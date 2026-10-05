import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../models/booking_model.dart';
import '../utils/app_api.dart';
import '../utils/data_utils.dart';
import '../widgets/date_time_picker_widget.dart';

/// Dialog ยืนยัน (WS09): เรียก onConfirm เมื่อผู้ใช้กดปุ่ม "ยืนยัน"
Future<void> showConfirmDialog(BuildContext context, Function onConfirm) async {
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
  // ---------- ข้อมูลนักศึกษา (ดึงจาก /profile ของผู้ที่ login) ----------
  Map<String, String> _student = const {
    'id': '-',
    'name': '-',
    'faculty': '-',
    'major': '-',
    'year': '-',
  };

  // ---------- ตัวแปรเก็บค่าที่ผู้ใช้เลือก ----------
  // ระบบจองนี้ใช้ยื่นเอกสารกู้ยืมอย่างเดียว (การจองเก่าที่เป็นประเภทอื่นจะถูกปรับเป็นประเภทนี้เมื่อแก้ไขและบันทึก)
  final String _serviceType = 'ยื่นเอกสารกู้ยืม';
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime; // ช่วงเวลา เช่น "09:00 - 09:30"
  bool _isLoading = false;

  // การจองเดิม (โหมดแก้ไข) ใช้คืนคิวของตัวเองให้ว่างตอนคำนวณคิวคงเหลือ
  DateTime? _originalDate;
  String? _originalTime;

  // ช่วงเวลาของวันที่เลือก (ดึงจาก server ตาม _selectedDate: เจ้าหน้าที่ปรับจำนวนรับ/ปิด/เพิ่มช่วงได้)
  // ก่อนโหลดเสร็จหรือโหลดไม่ได้ ใช้ค่ามาตรฐาน 09:00 - 16:00 ช่วงละ 30 นาที รับช่วงละ 5 คน
  List<Map<String, dynamic>> _timeSlots = _buildTimeSlots();

  // แปลง '09:00 - 09:30' เป็นนาทีที่เริ่ม
  static int _startMinute(String time) {
    final parts = time.split(' - ')[0].split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static List<Map<String, dynamic>> _defaultConfig() {
    String fmt(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

    return [
      for (int start = 9 * 60; start < 16 * 60; start += 30)
        if (start < 12 * 60 || start >= 13 * 60)
          {
            'time_slot': '${fmt(start)} - ${fmt(start + 30)}',
            'capacity': 5,
            'is_open': true,
            'booked': 0,
          },
    ];
  }

  // config: ช่วงเวลาจาก server [{time_slot, capacity, is_open, booked}]
  // ownSlot: slot ของการจองที่กำลังแก้ไข (ไม่นับเป็นคิวที่ถูกใช้)
  static List<Map<String, dynamic>> _buildTimeSlots({
    List<Map<String, dynamic>>? config,
    String? ownSlot,
  }) {
    final rows = [...(config ?? _defaultConfig())]
      ..sort(
        (a, b) =>
            (a['time_slot'] as String).compareTo(b['time_slot'] as String),
      );

    final List<Map<String, dynamic>> slots = [];

    for (final row in rows) {
      final String time = row['time_slot'] as String;
      final int capacity = (row['capacity'] as num).toInt();
      final bool isOpen = row['is_open'] == true;
      int used = (row['booked'] as num).toInt();
      if (time == ownSlot && used > 0) used--;

      slots.add({
        'time': time,
        'remaining': isOpen ? (capacity - used).clamp(0, capacity) : 0,
        'isClosed': !isOpen,
      });
    }

    // พักเที่ยง 12:00 - 13:00 (แสดงเมื่อไม่มีช่วงที่เจ้าหน้าที่เพิ่มมาเปิดในเวลานี้)
    final bool hasSlotInBreak = slots.any((s) {
      final int start = _startMinute(s['time'] as String);
      return start >= 12 * 60 && start < 13 * 60;
    });

    if (!hasSlotInBreak) {
      int index = slots.indexWhere(
        (s) => _startMinute(s['time'] as String) >= 13 * 60,
      );
      if (index == -1) index = slots.length;

      slots.insert(index, {
        'time': '12:00 - 13:00',
        'remaining': 0,
        'isBreak': true,
      });
    }

    return slots;
  }

  bool get _isEditMode => widget.bookingId != 0;

  @override
  void initState() {
    super.initState();
    // โหลดข้อมูลเดิมก่อน (โหมดแก้ไข) แล้วค่อยนับคิว เพื่อให้รู้ว่า slot ไหนเป็นของการจองนี้
    _loadStudent();
    _loadBookedDates();
    _loadOpenDays();
    _initData().then((_) => _fetchSlotCounts());
  }

  // วันที่ผู้ใช้จองไปแล้ว ใช้ทำเครื่องหมายในปฏิทินเลือกวันที่
  Set<DateTime> _bookedDates = {};

  // วันที่เจ้าหน้าที่เปิดรับการจอง { วันที่: {location, note} } (นักศึกษาเลือกได้เฉพาะวันเหล่านี้)
  // null = ยังโหลดไม่เสร็จ/โหลดไม่ได้ (เลือกวันได้ทุกวัน)
  Map<DateTime, Map<String, String>>? _openDays;

  Future<void> _loadOpenDays() async {
    try {
      final response = await AppAPI.get('/bookings/open-days');
      final json = jsonDecode(response.body);

      if (!mounted || json['isError'] == true || json['data'] is! List) return;

      final Map<DateTime, Map<String, String>> days = {};
      for (final row in json['data'] as List) {
        final date = DateUtils.dateOnly(
          DateFormat('dd-MM-yyyy').parse(row['date'] as String),
        );
        days[date] = {
          'location': (row['location'] ?? '').toString(),
          'note': (row['note'] ?? '').toString(),
        };
      }

      setState(() => _openDays = days);

      // จองใหม่: ถ้าวันนี้ยังไม่เปิดรับ ให้เลือกวันที่เปิดรับถัดไปให้เลย
      if (!_isEditMode &&
          days.isNotEmpty &&
          !days.containsKey(DateUtils.dateOnly(_selectedDate))) {
        final next = days.keys.toList()..sort();
        setState(() {
          _selectedDate = next.first;
          _selectedTime = null;
        });
        _fetchSlotCounts();
      }
    } catch (e) {
      // โหลดไม่ได้ก็เลือกวันได้ตามปกติ (server จะเช็กซ้ำตอนจองจริง)
    }
  }

  Future<void> _loadBookedDates() async {
    try {
      final response = await AppAPI.get('/bookings/list');
      final result = BookingResponse.fromJson(jsonDecode(response.body));

      if (!mounted || result.isError) return;
      setState(() {
        _bookedDates = result.data
            .map((b) => DateUtils.dateOnly(b.getBookingDate()))
            .toSet();
      });
    } catch (e) {
      // โหลดไม่ได้ก็แค่ไม่แสดงเครื่องหมาย ไม่กระทบการจอง
    }
  }

  Future<void> _loadStudent() async {
    try {
      final response = await AppAPI.get('/profile');
      final json = jsonDecode(response.body);
      final data = json['data'];

      if (json['isError'] == true || data is! List || data.isEmpty) return;

      final u = Map<String, dynamic>.from(data[0]);
      String v(String key) => (u[key] ?? '-').toString();

      if (!mounted) return;
      setState(() {
        _student = {
          'id': v('student_code'),
          'name':
              '${u['prefix'] ?? ''}${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'
                  .trim(),
          'faculty': v('faculty'),
          'major': v('major'),
          'year': v('year'),
        };
      });
    } catch (e) {
      // โหลดไม่ได้ให้แสดง "-" ไว้ (ไม่กระทบการจอง เพราะ server ใช้ user_id จาก token)
    }
  }

  // ---------- ดึงจำนวนที่จองแล้วต่อ time slot ของวันที่เลือก ----------
  Future<void> _fetchSlotCounts() async {
    final DateTime date = _selectedDate;
    List<Map<String, dynamic>>? config;

    try {
      final dateText = DateFormat('dd-MM-yyyy').format(date);
      var response = await AppAPI.get("/bookings/slots?date=$dateText");
      Map<String, dynamic> json = jsonDecode(response.body);

      if (!((json["isError"] ?? true) as bool) && json["data"] is List) {
        config = (json["data"] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      // ดึงไม่ได้ให้แสดงช่วงเวลามาตรฐานไปก่อน (server จะเช็กซ้ำตอนจองจริง)
    }

    // ผู้ใช้อาจเปลี่ยนวันที่ระหว่างรอ response
    if (!mounted || date != _selectedDate) return;

    final bool isOwnDate =
        _originalDate != null && DateUtils.isSameDay(_originalDate, date);

    setState(() {
      _timeSlots = _buildTimeSlots(
        config: config,
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

    return (
      (json["isError"] ?? true) as bool,
      (json["errorMessage"] ?? "") as String,
    );
  }

  Future<(bool, String)> _doDeleteBooking() async {
    Map<String, dynamic> postData = {"booking_id": widget.bookingId};

    final response = await AppAPI.post("/bookings/delete", postData);
    final json = jsonDecode(response.body);

    return (
      (json["isError"] ?? true) as bool,
      (json["errorMessage"] ?? "") as String,
    );
  }

  // ---------- การทำงานของปุ่ม ----------
  Future<void> _onSavePressed() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกช่วงเวลา')));
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardPink,
            ),
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
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textDark,
                    ),
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
                              _infoLine(
                                'รหัสนักศึกษา',
                                _student['id']!,
                                Colors.white,
                              ),
                              _infoLine(
                                'ชื่อ-นามสกุล',
                                _student['name']!,
                                Colors.white,
                              ),
                              _infoLine(
                                'คณะ',
                                _student['faculty']!,
                                Colors.white,
                              ),
                              _infoLine(
                                'สาขา',
                                _student['major']!,
                                Colors.white,
                              ),
                              _infoLine(
                                'ชั้นปี',
                                _student['year']!,
                                Colors.white,
                              ),
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
                          child: InputDecorator(
                            decoration: _fieldDecoration(),
                            child: Text(
                              _serviceType,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textDark,
                              ),
                            ),
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
                                bookedDates: _bookedDates,
                                openDates: _openDays?.keys.toSet(),
                                onDateChanged: (newDate) {
                                  setState(() {
                                    _selectedDate =
                                        newDate; // รับค่าจาก callback ของ widget ลูก
                                    _selectedTime =
                                        null; // เปลี่ยนวันที่แล้วให้เลือกเวลาใหม่
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((_openDays?[DateUtils.dateOnly(
                                        _selectedDate,
                                      )]?['location'] ??
                                      '')
                                  .isNotEmpty)
                                Text(
                                  '📍 สถานที่ยื่นเอกสาร: ${_openDays![DateUtils.dateOnly(_selectedDate)]!['location']}',
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                  ),
                                ),
                              if ((_openDays?[DateUtils.dateOnly(
                                        _selectedDate,
                                      )]?['note'] ??
                                      '')
                                  .isNotEmpty)
                                Text(
                                  _openDays![DateUtils.dateOnly(
                                    _selectedDate,
                                  )]!['note']!,
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    height: 1.5,
                                  ),
                                ),
                              const Text(
                                'กรุณานำเอกสารตัวจริงมาด้วย\n• บัตรนักศึกษา\n• บัตรประชาชน\n• เอกสาร กยศ.',
                                style: TextStyle(
                                  color: AppColors.textDark,
                                  height: 1.5,
                                ),
                              ),
                            ],
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.cardPink,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'ยกเลิก',
                                  style: TextStyle(color: AppColors.cardPink),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _onSavePressed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.cardPink,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  _isEditMode
                                      ? 'บันทึกการแก้ไข'
                                      : 'ยืนยันการจอง',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
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
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: textColor,
            ),
          ),
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$label : $value',
        style: TextStyle(color: color, fontSize: 14),
      ),
    );
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
