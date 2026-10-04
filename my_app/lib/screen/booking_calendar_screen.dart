import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/booking_model.dart';
import '../utils/app_api.dart';
import '../utils/data_utils.dart';

/// หน้าปฏิทินการจอง: วันที่มีการจองจะมีจุด/จำนวน กดวันเพื่อดูรายละเอียดด้านล่าง
class BookingCalendarScreen extends StatefulWidget {
  const BookingCalendarScreen({super.key});

  @override
  State<BookingCalendarScreen> createState() => _BookingCalendarScreenState();
}

class _BookingCalendarScreenState extends State<BookingCalendarScreen> {
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

  // booking ทั้งหมด จัดกลุ่มตามวัน (key = วันที่ไม่มีเวลา)
  Map<DateTime, List<BookingModel>> _byDay = {};
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateUtils.dateOnly(DateTime.now());
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final response = await AppAPI.get('/bookings/list');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final result = BookingResponse.fromJson(json);

      final Map<DateTime, List<BookingModel>> grouped = {};
      for (final b in result.data) {
        grouped
            .putIfAbsent(DateUtils.dateOnly(b.getBookingDate()), () => [])
            .add(b);
      }
      for (final list in grouped.values) {
        list.sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
      }

      if (!mounted) return;
      setState(() {
        _byDay = grouped;
        _errorMessage = result.isError ? result.errorMessage : '';
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

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                  ? Center(child: Text(_errorMessage))
                  : Column(
                      children: [
                        _buildMonthBar(),
                        _buildWeekdayRow(),
                        Expanded(flex: 5, child: _buildGrid()),
                        Expanded(flex: 4, child: _buildDetail()),
                      ],
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
              '🗓️ ปฏิทินการจอง',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildMonthBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardPink.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.cardPink,
            ),
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
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.cardPink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
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
    );
  }

  Widget _buildGrid() {
    final int daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    // DateTime.weekday: จันทร์=1 ... อาทิตย์=7 → ให้อาทิตย์เป็นคอลัมน์ 0
    final int leading = DateTime(_month.year, _month.month, 1).weekday % 7;
    final int rows = ((leading + daysInMonth) / 7).ceil();
    final DateTime today = DateUtils.dateOnly(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: List.generate(rows, (r) {
          return Expanded(
            child: Row(
              children: List.generate(7, (c) {
                final int day = r * 7 + c - leading + 1;
                if (day < 1 || day > daysInMonth) {
                  return const Expanded(child: SizedBox());
                }

                final DateTime date = DateTime(_month.year, _month.month, day);
                final int count = _byDay[date]?.length ?? 0;
                final bool isSelected = date == _selectedDay;
                final bool isToday = date == today;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDay = date),
                    child: Container(
                      margin: const EdgeInsets.all(3),
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
                            : (count > 0
                                  ? AppColors.gradientStart
                                  : Colors.white),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isToday
                              ? AppColors.cardPink
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.cardPink.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textDark,
                            ),
                          ),
                          if (count > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                count > 1 ? '💗×$count' : '💗',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDetail() {
    // การจองทั้งหมดของเดือนที่แสดงอยู่ เรียงตามวันที่แล้วตามเวลา
    final List<BookingModel> items =
        _byDay.entries
            .where(
              (e) => e.key.year == _month.year && e.key.month == _month.month,
            )
            .expand((e) => e.value)
            .toList()
          ..sort((a, b) {
            final d = a.getBookingDate().compareTo(b.getBookingDate());
            return d != 0 ? d : a.timeSlot.compareTo(b.timeSlot);
          });

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardPink.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📅 การจองเดือน${_monthNames[_month.month - 1]} (${items.length} รายการ)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🌷', style: TextStyle(fontSize: 32)),
                        SizedBox(height: 4),
                        Text(
                          'ไม่มีการจองในเดือนนี้',
                          style: TextStyle(color: AppColors.iconPurple),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final b = items[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          // ไฮไลต์รายการของวันที่เลือกบนปฏิทิน
                          border: Border.all(
                            color:
                                DateUtils.isSameDay(
                                  b.getBookingDate(),
                                  _selectedDay,
                                )
                                ? AppColors.cardPink
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cardPink,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                b.queueNo,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${DateUtil.getThaiDate(b.getBookingDate())}  ⏰ ${b.timeSlot}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    b.serviceType,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.iconPurple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
