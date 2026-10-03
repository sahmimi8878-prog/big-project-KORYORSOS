import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../models/booking_model.dart';
import '../utils/app_api.dart';
import '../utils/data_utils.dart';
import '../widgets/date_time_picker_widget.dart';

/// Dialog ยืนยัน (WS09): เรียก onConfirm เมื่อผู้ใช้กดปุ่ม "ยืนยัน"
Future<void> showConfirmDialog(
  BuildContext context,
  Function onConfirm,
) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('ยืนยันการทำรายการ'),
        content: const Text('คุณต้องการลบข้อมูลนี้ใช่หรือไม่?'),
        actions: <Widget>[
          TextButton(
            child: const Text('ยกเลิก'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
          ),
        ],
      );
    },
  );
}

/// หน้า "จองคิว กยศ."
/// - bookingId == 0  : จองใหม่ (สร้างข้อมูล)
/// - bookingId != 0  : แก้ไข / ลบ การจองเดิม (ดึงข้อมูลเดิมมาแสดงก่อน)
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, this.bookingId = 0});

  final int bookingId;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // ---------- ข้อมูลนักศึกษา (ตัวอย่าง: ในระบบจริงจะดึงจาก API/Login) ----------
  final Map<String, String> _student = const {
    'id': '6610210559',
    'name': 'ฉันท์ชนก ทองรัดแก้ว',
    'faculty': 'วิทยาศาสตร์',
    'major': 'ICT',
    'year': '4',
  };

  // ---------- ตัวแปรเก็บค่าที่ผู้ใช้เลือก ----------
  String _serviceType = 'ยื่นเอกสารกู้ยืม';
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime; // ช่วงเวลา เช่น "09:00 - 09:30"
  bool _isLoading = false;

  final List<String> _serviceTypes = const [
    'ยื่นเอกสารกู้ยืม',
    'ส่งเอกสารเพิ่มเติม',
    'แก้ไขเอกสาร',
    'เซ็นสัญญา',
    'รับเอกสาร',
    'ปรึกษาเจ้าหน้าที่',
  ];

  // จำนวนคิวสูงสุดต่อ 1 ช่วงเวลา
  static const int _slotCapacity = 5;

  // การจองเดิม (โหมดแก้ไข) ใช้คืนคิวของตัวเองให้ว่างตอนคำนวณคิวคงเหลือ
  DateTime? _originalDate;
  String? _originalTime;

  // ช่วงเวลา 09:00 - 16:00 ช่วงละ 30 นาที พักเที่ยง 12:00 - 13:00
  // จำนวนคิวคงเหลือ = _slotCapacity - จำนวนที่จองแล้ว (ดึงจาก server ตาม _selectedDate)
  List<Map<String, dynamic>> _timeSlots = _buildTimeSlots();

  // booked: จำนวนที่จองแล้วต่อ time slot, ownSlot: slot ของการจองที่กำลังแก้ไข (ไม่นับเป็นคิวที่ถูกใช้)
  static List<Map<String, dynamic>> _buildTimeSlots({
    Map<String, int> booked = const {},
    String? ownSlot,
  }) {
    const int openMinute = 9 * 60;
    const int closeMinute = 16 * 60;
    const int breakStart = 12 * 60;
    const int breakEnd = 13 * 60;
    const int slotLength = 30;

    String fmt(int minutes) =>
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

    final List<Map<String, dynamic>> slots = [];

    for (int start = openMinute; start < closeMinute; start += slotLength) {
      if (start >= breakStart && start < breakEnd) {
        if (start == breakStart) {
          slots.add({
            'time': '${fmt(breakStart)} - ${fmt(breakEnd)}',
            'remaining': 0,
            'isBreak': true,
          });
        }
        continue;
      }

      final String time = '${fmt(start)} - ${fmt(start + slotLength)}';
      int used = booked[time] ?? 0;
      if (time == ownSlot && used > 0) used--;

      slots.add({
        'time': time,
        'remaining': (_slotCapacity - used).clamp(0, _slotCapacity),
      });
    }

    return slots;
  }

  bool get _isEditMode => widget.bookingId != 0;

  @override
  void initState() {
    super.initState();
    // โหลดข้อมูลเดิมก่อน (โหมดแก้ไข) แล้วค่อยนับคิว เพื่อให้รู้ว่า slot ไหนเป็นของการจองนี้
    _initData().then((_) => _fetchSlotCounts());
  }

  // ---------- ดึงจำนวนที่จองแล้วต่อ time slot ของวันที่เลือก ----------
  Future<void> _fetchSlotCounts() async {
    final DateTime date = _selectedDate;
    final Map<String, int> booked = {};

    try {
      final dateText = DateFormat('dd-MM-yyyy').format(date);
      var response = await AppAPI.get("/bookings/slots?date=$dateText");
      Map<String, dynamic> json = jsonDecode(response.body);

      if (!((json["isError"] ?? true) as bool) && json["data"] is List) {
        for (final row in json["data"]) {
          booked[row["time_slot"] as String] = (row["booked"] as num).toInt();
        }
      }
    } catch (e) {
      // ดึงไม่ได้ให้แสดงคิวเต็มจำนวนไปก่อน (server จะเช็กซ้ำตอนจองจริง)
    }

    // ผู้ใช้อาจเปลี่ยนวันที่ระหว่างรอ response
    if (!mounted || date != _selectedDate) return;

    final bool isOwnDate = _originalDate != null &&
        DateUtils.isSameDay(_originalDate, date);

    setState(() {
      _timeSlots = _buildTimeSlots(
        booked: booked,
        ownSlot: isOwnDate ? _originalTime : null,
      );
    });
  }

  // ---------- ดึงข้อมูลการจองเดิม (โหมดแก้ไข) ----------
  Future<BookingModel> _getBookingModel() async {
    var response = await AppAPI.get("/bookings/${widget.bookingId}");
    Map<String, dynamic> json = jsonDecode(response.body);
    BookingResponse bookingResponse = BookingResponse.fromJson(json);

    if (bookingResponse.isError || bookingResponse.data.isEmpty) {
      throw Exception(
        bookingResponse.errorMessage.isEmpty
            ? 'ไม่พบข้อมูลการจอง'
            : bookingResponse.errorMessage,
      );
    }

    return bookingResponse.data[0];
  }

  Future<void> _initData() async {
    if (!_isEditMode) return;

    setState(() {
      _isLoading = true;
    });

    try {
      BookingModel model = await _getBookingModel();

      if (!mounted) return;
      setState(() {
        _serviceType = _serviceTypes.contains(model.serviceType)
            ? model.serviceType
            : _serviceTypes.first;
        _selectedDate = model.getBookingDate();
        _selectedTime = model.timeSlot;
        _originalDate = _selectedDate;
        _originalTime = model.timeSlot;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ---------- เรียก API ----------
  Map<String, dynamic> _buildPostData() {
    return {
      "service_type": _serviceType,
      "booking_date": DateFormat('dd-MM-yyyy').format(_selectedDate),
      "time_slot": _selectedTime,
    };
  }

  Future<(bool, String, String)> _doCreateBooking() async {
    final response = await AppAPI.post("/bookings/create", _buildPostData());
    final json = jsonDecode(response.body);

    final isError = (json["isError"] ?? true) as bool;
    final queueNo = isError ? "" : (json["data"]["queue_no"] as String);

    return (isError, (json["errorMessage"] ?? "") as String, queueNo);
  }

  Future<(bool, String)> _doUpdateBooking() async {
    Map<String, dynamic> postData = _buildPostData();
    postData["booking_id"] = widget.bookingId;

    final response = await AppAPI.post("/bookings/update", postData);
    final json = jsonDecode(response.body);

    return ((json["isError"] ?? true) as bool, (json["errorMessage"] ?? "") as String);
  }

  Future<(bool, String)> _doDeleteBooking() async {
    Map<String, dynamic> postData = {"booking_id": widget.bookingId};

    final response = await AppAPI.post("/bookings/delete", postData);
    final json = jsonDecode(response.body);

    return ((json["isError"] ?? true) as bool, (json["errorMessage"] ?? "") as String);
  }

  // ---------- การทำงานของปุ่ม ----------
  Future<void> _onSavePressed() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกช่วงเวลา')),
      );
      return;
    }

    try {
      if (!_isEditMode) {
        var (isError, errorMessage, queueNo) = await _doCreateBooking();

        if (!mounted) return;
        if (!isError) {
          _showSuccessDialog(queueNo);
        } else {
          _showErrorDialog(errorMessage);
        }
      } else {
        var (isError, errorMessage) = await _doUpdateBooking();

        if (!mounted) return;
        if (!isError) {
          Navigator.pop(context);
        } else {
          _showErrorDialog(errorMessage);
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้');
    }
  }

  Future<void> _onDeleteConfirmed() async {
    try {
      var (isError, errorMessage) = await _doDeleteBooking();

      if (!mounted) return;
      if (!isError) {
        Navigator.pop(context);
      } else {
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้');
    }
  }

  // ---------- Dialog ----------
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(content: Text(message)),
    );
  }

  void _showSuccessDialog(String queueNo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: AppColors.cardPink, size: 48),
            SizedBox(height: 8),
            Text('จองสำเร็จ', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryRow('เลขที่คิว', queueNo),
            _summaryRow('วันที่', DateUtil.getThaiDate(_selectedDate)),
            _summaryRow('เวลา', _selectedTime!),
            _summaryRow('ประเภทบริการ', _serviceType),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cardPink),
            onPressed: () {
              Navigator.pop(context); // ปิด dialog
              Navigator.pop(this.context); // กลับหน้ารายการ
            },
            child: const Text('ตกลง', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.iconPurple)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ---------- Header ไล่สีชมพู-ม่วง ----------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                  ),
                  Expanded(
                    child: Text(
                      _isEditMode ? 'แก้ไขการจอง' : 'จองคิว กยศ.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // ถ่วงสมดุลกับปุ่ม back
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ---------- การ์ดข้อมูลนักศึกษา (สีม่วง) ----------
                        _sectionCard(
                          color: AppColors.cardPurple,
                          textColor: Colors.white,
                          title: 'ข้อมูลนักศึกษา',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _infoLine('รหัสนักศึกษา', _student['id']!, Colors.white),
                              _infoLine('ชื่อ-นามสกุล', _student['name']!, Colors.white),
                              _infoLine('คณะ', _student['faculty']!, Colors.white),
                              _infoLine('สาขา', _student['major']!, Colors.white),
                              _infoLine('ชั้นปี', _student['year']!, Colors.white),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ---------- ปุ่มลบ (เฉพาะโหมดแก้ไข) ----------
                        if (_isEditMode)
                          Container(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(Icons.delete),
                              color: Colors.redAccent,
                              splashColor: Colors.red.withValues(alpha: 0.1),
                              onPressed: () {
                                showConfirmDialog(context, _onDeleteConfirmed);
                              },
                            ),
                          ),

                        // ---------- เลือกประเภทบริการ ----------
                        _whiteCard(
                          title: 'ประเภทบริการ',
                          child: DropdownButtonFormField<String>(
                            // key ทำให้ dropdown สร้างใหม่เมื่อค่าถูกเปลี่ยนหลังโหลดข้อมูลเดิม
                            key: ValueKey(_serviceType),
                            initialValue: _serviceType,
                            decoration: _fieldDecoration(),
                            items: _serviceTypes
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _serviceType = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ---------- เลือกวันเวลา (widget ลูก + callback) ----------
                        _whiteCard(
                          title: 'วันเวลา',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DateTimePickerWidget(
                                selectedDate: _selectedDate,
                                selectedTime: _selectedTime,
                                slots: _timeSlots,
                                onDateChanged: (newDate) {
                                  setState(() {
                                    _selectedDate = newDate; // รับค่าจาก callback ของ widget ลูก
                                    _selectedTime = null; // เปลี่ยนวันที่แล้วให้เลือกเวลาใหม่
                                  });
                                  _fetchSlotCounts(); // นับคิวคงเหลือของวันที่ใหม่
                                },
                                onTimeChanged: (newTime) {
                                  setState(() {
                                    _selectedTime = newTime;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ---------- หมายเหตุ (สีครีม) ----------
                        _sectionCard(
                          color: AppColors.cardCream,
                          textColor: AppColors.textOnPink,
                          title: 'หมายเหตุ',
                          child: const Text(
                            'กรุณานำเอกสารตัวจริงมาด้วย\n• บัตรนักศึกษา\n• บัตรประชาชน\n• เอกสาร กยศ.',
                            style: TextStyle(color: AppColors.textDark, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ---------- ปุ่มยืนยัน / ยกเลิก ----------
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: AppColors.cardPink),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('ยกเลิก',
                                    style: TextStyle(color: AppColors.cardPink)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _onSavePressed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.cardPink,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  _isEditMode ? 'บันทึกการแก้ไข' : 'ยืนยันการจอง',
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Widget ย่อยช่วยจัดหน้าตา ----------
  Widget _sectionCard({
    required Color color,
    required Color textColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _whiteCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text('$label : $value', style: TextStyle(color: color, fontSize: 14)),
    );
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
