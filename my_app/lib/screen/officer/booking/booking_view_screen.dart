import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_api.dart';
import '../../../utils/data_utils.dart';
import '../../../widgets/booking_date_picker_dialog.dart';

/// จำนวนที่รับต่อช่วงเวลาถ้าเจ้าหน้าที่ไม่ได้ตั้งค่า (ตรงกับ DEFAULT_CAPACITY ใน models/bookings.js)
const int _defaultCapacity = 5;

/// การจองของนักศึกษา 1 รายการ (จาก GET /api/admin/bookings)
class _StudentBooking {
  final int bookingId;
  final String studentCode;
  final String studentName;
  final String serviceType;
  final DateTime date;
  final String timeSlot;
  final String queueNo;

  _StudentBooking.fromJson(Map<String, dynamic> json)
    : bookingId = json['booking_id'] as int,
      studentCode = (json['student_code'] ?? '-').toString(),
      studentName = (json['student_name'] ?? '-').toString(),
      serviceType = (json['service_type'] ?? '').toString(),
      date = DateUtils.dateOnly(
        DateFormat('dd-MM-yyyy').parse(json['booking_date'] as String),
      ),
      timeSlot = (json['time_slot'] ?? '').toString(),
      queueNo = (json['queue_no'] ?? '').toString();
}

/// หน้าแสดงข้อมูลการจองของเจ้าหน้าที่
/// ปฏิทินเลือกวัน → แสดงรายชื่อนักศึกษาที่จองของวันนั้น แยกตามช่วงเวลา
/// editable = true (เมนู "แก้ไขข้อมูลการจอง"): กดแก้ไขรายชื่อเพื่อย้ายวันและช่วงเวลาได้
class BookingViewScreen extends StatefulWidget {
  const BookingViewScreen({
    super.key,
    this.editable = false,
    this.embedded = false,
  });

  /// true = ฝังในหน้าจัดการระบบการจอง (ไม่แสดงหัวหน้าและปุ่มย้อนกลับของตัวเอง)
  final bool embedded;

  final bool editable;

  @override
  State<BookingViewScreen> createState() => _BookingViewScreenState();
}

class _BookingViewScreenState extends State<BookingViewScreen> {
  static const List<String> _monthNames = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];
  static const List<String> _weekdays = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

  Map<DateTime, List<_StudentBooking>> _byDay = {};
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateUtils.dateOnly(DateTime.now());
  // จำนวนที่เปิดรับต่อช่วงเวลาของวันที่เลือก { '09:00 - 09:30': 5 }
  Map<String, int> _capacity = {};
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchCapacity();
  }

  void _selectDay(DateTime date) {
    setState(() => _selectedDay = date);
    _fetchCapacity();
  }

  Future<void> _fetchCapacity() async {
    final DateTime day = _selectedDay;

    try {
      final dateText = DateFormat('dd-MM-yyyy').format(day);
      final response = await AppAPI.get('/bookings/slots?date=$dateText');
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted || day != _selectedDay || json['isError'] == true) return;

      setState(() {
        _capacity = {
          for (final row in json['data'] as List)
            row['time_slot'] as String: (row['capacity'] as num).toInt(),
        };
      });
    } catch (e) {
      // โหลดไม่ได้ก็ใช้ค่าเริ่มต้นไปก่อน
    }
  }

  Future<void> _fetchData() async {
    try {
      final response = await AppAPI.get('/admin/bookings');
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;

      if (json['isError'] == true) {
        setState(() {
          _errorMessage = (json['errorMessage'] ?? 'โหลดข้อมูลไม่ได้')
              .toString();
          _isLoading = false;
        });
        return;
      }

      final Map<DateTime, List<_StudentBooking>> grouped = {};
      for (final row in json['data'] as List) {
        final b = _StudentBooking.fromJson(Map<String, dynamic>.from(row));
        grouped.putIfAbsent(b.date, () => []).add(b);
      }

      setState(() {
        _byDay = grouped;
        _errorMessage = '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้';
        _isLoading = false;
      });
    }
  }

  // เปิดฟอร์มย้ายวัน/ช่วงเวลาของการจอง แล้วโหลดข้อมูลใหม่เมื่อบันทึกสำเร็จ
  Future<void> _edit(_StudentBooking b) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ChangeBookingDialog(booking: b),
    );

    if (saved == true) {
      await _fetchData();
      await _fetchCapacity();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('แก้ไขข้อมูลการจองเรียบร้อย')),
        );
      }
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.embedded) _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                  ? Center(child: Text(_errorMessage))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // จอกว้าง: ปฏิทินซ้าย / รายละเอียดขวา (เลื่อนแยกกัน)
                        if (constraints.maxWidth >= 800) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: _buildCalendarCard(),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: _buildDayDetailCard(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // จอแคบ: เรียงบน-ล่าง
                        return RefreshIndicator(
                          onRefresh: _fetchData,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            children: [
                              _buildCalendarCard(),
                              const SizedBox(height: 16),
                              _buildDayDetailCard(),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
              widget.editable ? 'แก้ไขข้อมูลการจอง' : 'แสดงข้อมูลการจอง',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          IconButton(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }

  // ---------- การ์ดปฏิทิน ----------
  Widget _buildCalendarCard() {
    final int daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final int leading = DateTime(_month.year, _month.month, 1).weekday % 7;
    final int rows = ((leading + daysInMonth) / 7).ceil();
    final DateTime today = DateUtils.dateOnly(DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: _cardDecoration(radius: 24),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.cardPink,
              ),
              Expanded(
                child: Text(
                  '🌸 ${_monthNames[_month.month - 1]} ${_month.year + 543}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.cardPink,
              ),
            ],
          ),
          Row(
            children: _weekdays
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.iconPurple,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          for (int r = 0; r < rows; r++)
            Row(
              children: List.generate(7, (c) {
                final int day = r * 7 + c - leading + 1;
                if (day < 1 || day > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 56));
                }
                return Expanded(
                  child: _buildDayCell(
                    DateTime(_month.year, _month.month, day),
                    today,
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime date, DateTime today) {
    final int count = _byDay[date]?.length ?? 0;
    final bool isSelected = date == _selectedDay;
    final bool isToday = date == today;

    return GestureDetector(
      onTap: () => _selectDay(date),
      child: Container(
        height: 56,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.cardPink, Color(0xFFB9A7F0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : (count > 0 ? AppColors.gradientStart : null),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isToday ? AppColors.cardPink : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textDark,
              ),
            ),
            if (count > 0)
              Text(
                '👩‍🎓$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textOnPink,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- การ์ดรายละเอียดของวันที่เลือก (แยกตามช่วงเวลา) ----------
  Widget _buildDayDetailCard() {
    final List<_StudentBooking> items = _byDay[_selectedDay] ?? [];

    // จัดกลุ่มตาม time slot เรียงตามเวลา
    final Map<String, List<_StudentBooking>> bySlot = {};
    for (final b in items) {
      bySlot.putIfAbsent(b.timeSlot, () => []).add(b);
    }
    final slots = bySlot.keys.toList()..sort();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📅 ${DateUtil.getThaiDate(_selectedDay)}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            items.isEmpty
                ? 'ยังไม่มีนักศึกษาจอง'
                : 'มีผู้จองทั้งหมด ${items.length} คน',
            style: const TextStyle(color: AppColors.iconPurple),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Text('🌷', style: TextStyle(fontSize: 32)),
                    SizedBox(height: 4),
                    Text(
                      'ไม่มีการจองในวันนี้',
                      style: TextStyle(color: AppColors.iconPurple),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final slot in slots) ...[
              _buildSlotSection(slot, bySlot[slot]!),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _buildSlotSection(String slot, List<_StudentBooking> students) {
    final int capacity = _capacity[slot] ?? _defaultCapacity;
    final bool isFull = students.length >= capacity;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '⏰ $slot',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isFull
                      ? AppColors.cardPurple
                      : AppColors.gradientStart,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${students.length}/$capacity${isFull ? ' เต็ม' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textOnPink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final s in students)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardPink,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      s.queueNo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.studentCode}  ${s.studentName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          s.serviceType,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.iconPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.editable)
                    IconButton(
                      tooltip: 'แก้ไขวันและช่วงเวลา',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _edit(s),
                      icon: const Icon(
                        Icons.edit_rounded,
                        size: 20,
                        color: AppColors.cardPink,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration({required double radius}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: AppColors.cardPink.withValues(alpha: 0.18),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

/// ฟอร์มย้ายวัน/ช่วงเวลาของการจอง (เปลี่ยนได้เฉพาะวันและช่วงเวลา) คืน true เมื่อบันทึกสำเร็จ
class _ChangeBookingDialog extends StatefulWidget {
  const _ChangeBookingDialog({required this.booking});

  final _StudentBooking booking;

  @override
  State<_ChangeBookingDialog> createState() => _ChangeBookingDialogState();
}

class _ChangeBookingDialogState extends State<_ChangeBookingDialog> {
  late DateTime _date;
  String? _slot;
  Set<DateTime>?
  _openDates; // วันที่เปิดรับการจอง (null = ยังโหลดไม่เสร็จ/โหลดไม่ได้)
  List<Map<String, dynamic>> _rows =
      []; // รอบเวลาของวันที่เลือก จาก /bookings/slots
  bool _loadingSlots = true;
  bool _isSaving = false;
  String _error = '';

  _StudentBooking get _b => widget.booking;

  @override
  void initState() {
    super.initState();
    _date = _b.date;
    _slot = _b.timeSlot;
    _loadOpenDates();
    _loadSlots();
  }

  Future<void> _loadOpenDates() async {
    try {
      final response = await AppAPI.get('/bookings/open-days');
      final json = jsonDecode(response.body);

      if (!mounted || json['isError'] == true || json['data'] is! List) return;

      setState(() {
        _openDates = {
          for (final row in json['data'] as List)
            DateUtils.dateOnly(
              DateFormat('dd-MM-yyyy').parse(row['date'] as String),
            ),
          _b.date, // วันเดิมของการจองเลือกกลับมาได้เสมอ
        };
      });
    } catch (e) {
      // โหลดไม่ได้ก็เลือกวันได้ทุกวัน (server จะเช็กซ้ำตอนบันทึก)
    }
  }

  Future<void> _loadSlots() async {
    final DateTime date = _date;
    setState(() => _loadingSlots = true);

    try {
      final response = await AppAPI.get(
        '/bookings/slots?date=${DateFormat('dd-MM-yyyy').format(date)}',
      );
      final json = jsonDecode(response.body);

      if (!mounted || date != _date) return;

      setState(() {
        _rows = json['isError'] == true
            ? []
            : (json['data'] as List)
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
        _loadingSlots = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows = [];
        _loadingSlots = false;
        _error = 'โหลดรอบเวลาไม่ได้';
      });
    }
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showBookingDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _date.isBefore(today) ? _date : today,
      bookedDates: const {},
      openDates: _openDates,
    );

    if (picked == null || DateUtils.dateOnly(picked) == _date) return;

    setState(() {
      _date = DateUtils.dateOnly(picked);
      _slot = null; // เปลี่ยนวันแล้วต้องเลือกรอบเวลาใหม่
      _error = '';
    });
    _loadSlots();
  }

  bool get _unchanged => _date == _b.date && _slot == _b.timeSlot;

  Future<void> _save() async {
    if (_slot == null) {
      setState(() => _error = 'กรุณาเลือกช่วงเวลา');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = '';
    });

    try {
      final response = await AppAPI.post('/admin/bookings/update', {
        'booking_id': _b.bookingId,
        'service_type': _b.serviceType,
        'booking_date': DateFormat('dd-MM-yyyy').format(_date),
        'time_slot': _slot,
      });
      final json = jsonDecode(response.body);

      if (!mounted) return;

      if (json['isError'] == true) {
        setState(() {
          _isSaving = false;
          _error = (json['errorMessage'] ?? 'บันทึกไม่สำเร็จ').toString();
        });
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '✏️ แก้ไขวันและช่วงเวลา',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_b.queueNo}  ${_b.studentCode} ${_b.studentName}\n${_b.serviceType}',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'วันที่',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(DateUtil.getThaiDate(_date))),
                      const Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: AppColors.cardPink,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ช่วงเวลา',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              if (_loadingSlots)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _rows.map(_slotChip).toList(),
                ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(color: AppColors.iconPurple),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardPink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: (_isSaving || _unchanged) ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'บันทึก',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // รอบเวลา 1 รอบ: เหลือกี่คิว (ไม่นับการจองนี้เองถ้าเป็นรอบเดิมของวันเดิม)
  Widget _slotChip(Map<String, dynamic> row) {
    final String time = row['time_slot'] as String;
    final int capacity = (row['capacity'] as num).toInt();
    int booked = (row['booked'] as num).toInt();
    final bool isOpen = row['is_open'] == true;

    if (_date == _b.date && time == _b.timeSlot && booked > 0) booked--;

    final int remaining = isOpen ? (capacity - booked).clamp(0, capacity) : 0;
    final bool disabled = remaining == 0;
    final bool isSelected = _slot == time;

    return InkWell(
      onTap: disabled ? null : () => setState(() => _slot = time),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.chipFull
              : (isSelected ? AppColors.cardPink : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.cardPink : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              time,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: disabled
                    ? AppColors.chipFullText
                    : (isSelected ? Colors.white : AppColors.textDark),
              ),
            ),
            Text(
              !isOpen
                  ? 'ปิดรับ'
                  : (remaining == 0 ? 'เต็ม' : 'เหลือ $remaining คิว'),
              style: TextStyle(
                fontSize: 11,
                color: disabled
                    ? AppColors.chipFullText
                    : (isSelected ? Colors.white70 : AppColors.iconPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
