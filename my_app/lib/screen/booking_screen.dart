import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../widgets/time_slot_widget.dart';
 
/// หน้า "จองคิว กยศ." สร้างตามเทคนิคที่สอนใน WS08 (Create Data):
/// - StatefulWidget + initState เพื่อตั้งค่าเริ่มต้น
/// - เก็บวันที่/เวลาในตัวแปร state แล้ว refresh UI ด้วย setState
/// - ใช้ widget ลูก (TimeSlotWidget) ที่ส่งค่ากลับผ่าน callback
/// - ใช้ class DateTime ในการจัดการวันที่
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});
 
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
  String? _selectedTime;
 
  final List<String> _serviceTypes = const [
    'ยื่นเอกสารกู้ยืม',
    'ส่งเอกสารเพิ่มเติม',
    'แก้ไขเอกสาร',
    'เซ็นสัญญา',
    'รับเอกสาร',
    'ปรึกษาเจ้าหน้าที่',
  ];
 
  // mock ช่วงเวลา+จำนวนคิวคงเหลือ (ระบบจริงควรดึงจาก server ตาม _selectedDate)
  final List<Map<String, dynamic>> _timeSlots = const [
    {'time': '09:00 - 09:30', 'remaining': 3},
    {'time': '09:30 - 10:00', 'remaining': 5},
    {'time': '10:00 - 10:30', 'remaining': 0},
    {'time': '10:30 - 11:00', 'remaining': 2},
  ];
 
  @override
  void initState() {
    super.initState();
    _selectedTime = null;
  }
 
  // ฟังก์ชันเลือกวันที่ (รูปแบบเดียวกับ _pickDate ใน workshop)
  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null; // เปลี่ยนวันที่แล้วให้เลือกเวลาใหม่
      });
    }
  }
 
  String get _formattedDate {
    const months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final buddhistYear = _selectedDate.year + 543;
    return '${_selectedDate.day} ${months[_selectedDate.month - 1]} $buddhistYear';
  }
 
  void _confirmBooking() {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกช่วงเวลา')),
      );
      return;
    }
 
    // จำลองเลขคิวที่ได้จากระบบ
    const queueNo = 'A015';
 
    showDialog(
      context: context,
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
            _summaryRow('วันที่', _formattedDate),
            _summaryRow('เวลา', _selectedTime!),
            _summaryRow('ประเภทบริการ', _serviceType),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ปิด dialog
              Navigator.pop(context); // กลับหน้าหลัก
            },
            child: const Text('กลับหน้าหลัก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cardPink),
            onPressed: () => Navigator.pop(context),
            child: const Text('ดูรายละเอียด', style: TextStyle(color: Colors.white)),
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
                  const Expanded(
                    child: Text(
                      'จองคิว กยศ.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
              child: ListView(
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
 
                  // ---------- เลือกประเภทบริการ ----------
                  _whiteCard(
                    title: 'ประเภทบริการ',
                    child: DropdownButtonFormField<String>(
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
 
                  // ---------- เลือกวันที่ ----------
                  _whiteCard(
                    title: 'วันที่',
                    child: InkWell(
                      onTap: () => _pickDate(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formattedDate, style: const TextStyle(fontSize: 15)),
                            const Icon(Icons.calendar_today, color: AppColors.cardPink, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
 
                  // ---------- เลือกเวลา (widget ลูก + callback) ----------
                  _whiteCard(
                    title: 'เวลา',
                    child: TimeSlotWidget(
                      selectedTime: _selectedTime,
                      slots: _timeSlots,
                      onTimeSelected: (newTime) {
                        setState(() {
                          _selectedTime = newTime; // รับค่าจาก callback ของ widget ลูก
                        });
                      },
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
                          child: const Text('ยกเลิก', style: TextStyle(color: AppColors.cardPink)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _confirmBooking,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.cardPink,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            'ยืนยันการจอง',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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