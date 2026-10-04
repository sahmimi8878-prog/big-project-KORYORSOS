import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_api.dart';
import 'booking_edit_screen.dart';

const List<String> _monthShort = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

const List<String> _weekdayNames = [
  'อาทิตย์',
  'จันทร์',
  'อังคาร',
  'พุธ',
  'พฤหัสบดี',
  'ศุกร์',
  'เสาร์',
];

String _thai(DateTime d) =>
    '${d.day} ${_monthShort[d.month - 1]} ${d.year + 543}';

/// วันที่เจ้าหน้าที่ตั้งค่าไว้ 1 วัน (จาก GET /api/admin/open-days)
class _Day {
  final DateTime date;
  final bool open;
  final String location;
  final String note;
  final List<Map<String, dynamic>>
  slots; // {time_slot, capacity, is_open, booked}

  _Day.fromJson(Map<String, dynamic> json)
    : date = DateUtils.dateOnly(
        DateFormat('dd-MM-yyyy').parse(json['date'] as String),
      ),
      open = json['is_open'] == true,
      location = (json['location'] ?? '').toString(),
      note = (json['note'] ?? '').toString(),
      slots = [
        for (final s in json['slots'] as List) Map<String, dynamic>.from(s),
      ];

  int get capacity => open
      ? slots
            .where((s) => s['is_open'] == true)
            .fold(0, (a, s) => a + (s['capacity'] as num).toInt())
      : 0;
  int get booked => slots.fold(0, (a, s) => a + (s['booked'] as num).toInt());
  int get openSlots =>
      open ? slots.where((s) => s['is_open'] == true).length : 0;

  // ใช้จับกลุ่มวันที่ติดกันเป็น "รอบ" เดียว: เปิด/ปิดเหมือนกัน และสถานที่เหมือนกัน
  // (ไม่เอารอบเวลา/จำนวนรับมาเทียบ เพราะแก้ต่างกันรายวันได้ แต่ยังเป็นรอบที่เปิดพร้อมกัน)
  String get signature => '$open|$location|$note';
}

/// รอบการจอง = ช่วงวันที่ติดกันที่เปิดรับพร้อมกัน (สถานที่เดียวกัน)
class _Round {
  final List<_Day> days;

  _Round(this.days);

  DateTime get start => days.first.date;
  DateTime get end => days.last.date;
  bool get open => days.first.open;
  String get location => days.first.location;
  String get note => days.first.note;
  bool get isPast => end.isBefore(DateUtils.dateOnly(DateTime.now()));
  // รอบเวลาต่อวัน / จำนวนรับต่อวัน: ถ้าแต่ละวันไม่เท่ากันแสดงเป็นช่วง เช่น 60-63
  String get openSlotsLabel => _rangeLabel(days.map((d) => d.openSlots));
  String get capacityPerDayLabel => _rangeLabel(days.map((d) => d.capacity));

  static String _rangeLabel(Iterable<int> values) {
    final int lo = values.reduce((a, b) => a < b ? a : b);
    final int hi = values.reduce((a, b) => a > b ? a : b);
    return lo == hi ? '$lo' : '$lo-$hi';
  }

  int get capacity => days.fold(0, (a, d) => a + d.capacity);
  int get booked => days.fold(0, (a, d) => a + d.booked);

  String get range {
    if (start == end) return _thai(start);
    if (start.year == end.year && start.month == end.month) {
      return '${start.day} - ${end.day} ${_monthShort[end.month - 1]} ${end.year + 543}';
    }
    return '${start.day} ${_monthShort[start.month - 1]} - ${_thai(end)}';
  }

  // ช่วงเวลาตั้งแต่รอบแรกถึงรอบสุดท้ายของวัน เช่น 09:00 - 16:00
  String get timeSpan {
    final names =
        days
            .expand((d) => d.slots.map((s) => s['time_slot'] as String))
            .toList()
          ..sort();
    if (names.isEmpty) return '-';

    final ends = names.map((n) => n.split(' - ')[1]).toList()..sort();
    return '${names.first.split(' - ')[0]} - ${ends.last}';
  }
}

/// หน้าแก้ไขข้อมูลการจองของเจ้าหน้าที่: สรุปรอบการจองทั้งหมดก่อน แล้วกดแก้ไขแต่ละรอบได้
class BookingRoundsScreen extends StatefulWidget {
  const BookingRoundsScreen({super.key, this.embedded = false});

  /// true = ฝังในหน้าจัดการระบบการจอง (ไม่แสดงหัวหน้าและปุ่มย้อนกลับของตัวเอง)
  final bool embedded;

  @override
  State<BookingRoundsScreen> createState() => _BookingRoundsScreenState();
}

class _BookingRoundsScreenState extends State<BookingRoundsScreen> {
  List<_Round> _rounds = [];
  final Set<DateTime> _expanded =
      {}; // รอบที่กางดูรายวันอยู่ (key = วันแรกของรอบ)
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final response = await AppAPI.get(
        '/admin/open-days?from=01-01-2000&to=31-12-2100',
      );
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

      final days =
          (json['data'] as List)
              .map((e) => _Day.fromJson(Map<String, dynamic>.from(e)))
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

      // จับวันที่ติดกันและตั้งค่าเหมือนกันเป็นรอบเดียว
      final List<_Round> rounds = [];
      for (final d in days) {
        final last = rounds.isEmpty ? null : rounds.last;

        if (last != null &&
            last.end.add(const Duration(days: 1)) == d.date &&
            last.days.last.signature == d.signature) {
          last.days.add(d);
        } else {
          rounds.add(_Round([d]));
        }
      }

      setState(() {
        // แสดงเฉพาะรอบที่เปิดให้จองอยู่ (ซ่อนรอบที่ปิดรับและรอบที่ผ่านมาแล้ว)
        _rounds = rounds.where((r) => r.open && !r.isPast).toList();
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

  // ปุ่ม + : เปิดหน้าเพิ่มข้อมูลการจอง (เปิดรับรอบใหม่) แล้วโหลดรายการใหม่เมื่อกลับมา
  Future<void> _add() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BookingEditScreen()),
    );

    _fetchData();
  }

  // แก้ไขทั้งรอบ (from-to ของรอบ) หรือวันเดียว (from = to = วันนั้น)
  Future<void> _edit(DateTime from, DateTime to) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BookingEditScreen(initialFrom: from, initialTo: to),
      ),
    );

    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        tooltip: 'เพิ่มข้อมูลการจอง',
        backgroundColor: AppColors.cardPink,
        onPressed: _add,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.embedded) _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                  ? Center(child: Text(_errorMessage))
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text(
                            '📋 รอบการจองทั้งหมด',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_rounds.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Center(
                                child: Column(
                                  children: [
                                    Text('🌷', style: TextStyle(fontSize: 32)),
                                    SizedBox(height: 4),
                                    Text(
                                      'ยังไม่มีรอบที่เปิดให้จอง กดปุ่ม + เพื่อเพิ่มข้อมูลการจอง',
                                      style: TextStyle(
                                        color: AppColors.iconPurple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, c) {
                                // จอกว้างวางการ์ดสองคอลัมน์
                                final int cols = c.maxWidth >= 900 ? 2 : 1;
                                final double w =
                                    (c.maxWidth - (cols - 1) * 12) / cols;

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: _rounds
                                      .map(
                                        (r) => SizedBox(
                                          width: w,
                                          child: _buildRoundCard(r),
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                            ),
                        ],
                      ),
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
          const Expanded(
            child: Text(
              'แก้ไขข้อมูลการจอง',
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

  // ---------- การ์ดของแต่ละรอบ ----------
  Widget _buildRoundCard(_Round r) {
    const String status = 'เปิดรับ';
    const Color statusColor = Color(0xffd8f5e3);
    const Color statusText = Color(0xff1a8f4d);

    return Opacity(
      opacity: 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(120, 90, 160, 0.15),
              blurRadius: 15,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xffffe5f4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: Color(0xffb47aaa),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.range,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff765982),
                        ),
                      ),
                      Text(
                        r.days.length == 1 ? '1 วัน' : '${r.days.length} วัน',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusText,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'แก้ไขรอบนี้',
                  onPressed: () => _edit(r.start, r.end),
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: AppColors.cardPink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (r.location.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.cardPink,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r.location,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('⏰ ${r.timeSpan}'),
                _chip('${r.openSlotsLabel} รอบ/วัน'),
                _chip('รับ ${r.capacityPerDayLabel} คน/วัน'),
                _chip('จองแล้ว ${r.booked}/${r.capacity}'),
              ],
            ),
            if (r.days.length > 1) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    if (!_expanded.remove(r.start)) _expanded.add(r.start);
                  }),
                  icon: Icon(
                    _expanded.contains(r.start)
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.iconPurple,
                  ),
                  label: Text(
                    _expanded.contains(r.start)
                        ? 'ซ่อนรายวัน'
                        : 'ดูรายวัน (${r.days.length} วัน)',
                    style: const TextStyle(color: AppColors.iconPurple),
                  ),
                ),
              ),
            ],
            if (_expanded.contains(r.start) || r.days.length == 1) ...[
              const Divider(height: 16),
              for (final d in r.days) _buildDayRow(d),
            ],
          ],
        ),
      ),
    );
  }

  // แถวของแต่ละวันในรอบ: กดดินสอเพื่อแก้ไขรายละเอียดเฉพาะวันนั้น
  Widget _buildDayRow(_Day d) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'วัน${_weekdayNames[d.date.weekday % 7]}ที่ ${_thai(d.date)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '${d.openSlots} รอบ • รับ ${d.capacity} คน • จองแล้ว ${d.booked}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.iconPurple,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'แก้ไขเฉพาะวันนี้',
            visualDensity: VisualDensity.compact,
            onPressed: () => _edit(d.date, d.date),
            icon: const Icon(
              Icons.edit_rounded,
              size: 20,
              color: AppColors.cardPink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.textDark),
      ),
    );
  }
}
