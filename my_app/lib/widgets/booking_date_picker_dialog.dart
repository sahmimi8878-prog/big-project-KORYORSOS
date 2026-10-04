import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// ปฏิทินเลือกวันที่จอง: วันที่ผู้ใช้จองไปแล้วจะมีสีชมพูอ่อนพร้อม 💗
/// คืนค่าวันที่ที่เลือก หรือ null ถ้ากดยกเลิก
Future<DateTime?> showBookingDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required Set<DateTime> bookedDates, // วันที่ไม่มีเวลา (DateUtils.dateOnly)
  Set<DateTime>? openDates, // ถ้าระบุ จะเลือกได้เฉพาะวันที่เปิดรับการจอง
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (context) => _BookingDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      bookedDates: bookedDates,
      openDates: openDates,
    ),
  );
}

class _BookingDatePickerDialog extends StatefulWidget {
  const _BookingDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.bookedDates,
    this.openDates,
  });

  final Set<DateTime>? openDates;
  final DateTime initialDate;
  final DateTime firstDate;
  final Set<DateTime> bookedDates;

  @override
  State<_BookingDatePickerDialog> createState() =>
      _BookingDatePickerDialogState();
}

class _BookingDatePickerDialogState extends State<_BookingDatePickerDialog> {
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

  late DateTime _month;
  late DateTime _selected;
  late final DateTime _first;

  @override
  void initState() {
    super.initState();
    _selected = DateUtils.dateOnly(widget.initialDate);
    _first = DateUtils.dateOnly(widget.firstDate);
    _month = DateTime(_selected.year, _selected.month);
  }

  bool get _canGoPrev => DateTime(
    _month.year,
    _month.month,
  ).isAfter(DateTime(_first.year, _first.month));

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final int daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final int leading = DateTime(_month.year, _month.month, 1).weekday % 7;
    final int rows = ((leading + daysInMonth) / 7).ceil();
    final DateTime today = DateUtils.dateOnly(DateTime.now());

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🗓️ เลือกวันที่จอง',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _canGoPrev ? () => _changeMonth(-1) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                      color: AppColors.cardPink,
                    ),
                    Expanded(
                      child: Text(
                        '🌸 ${_monthNames[_month.month - 1]} ${_month.year + 543}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
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
              ),
              const SizedBox(height: 8),
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
                      return const Expanded(child: SizedBox(height: 46));
                    }
                    return Expanded(
                      child: _buildDay(
                        DateTime(_month.year, _month.month, day),
                        today,
                      ),
                    );
                  }),
                ),
              const SizedBox(height: 10),
              _buildLegend(),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(color: AppColors.iconPurple),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardPink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text(
                      'ตกลง',
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

  Widget _buildDay(DateTime date, DateTime today) {
    final bool disabled =
        date.isBefore(_first) ||
        (widget.openDates != null && !widget.openDates!.contains(date));
    final bool isBooked = widget.bookedDates.contains(date);
    final bool isSelected = date == _selected;
    final bool isToday = date == today;

    return GestureDetector(
      onTap: disabled ? null : () => setState(() => _selected = date),
      child: Container(
        height: 46,
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
              : (isBooked ? AppColors.gradientStart : null),
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
                color: isSelected
                    ? Colors.white
                    : (disabled ? Colors.grey.shade400 : AppColors.textDark),
              ),
            ),
            if (isBooked) const Text('💗', style: TextStyle(fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        _legendItem(color: AppColors.gradientStart, label: '💗 จองไปแล้ว'),
        _legendItem(color: AppColors.cardPink, label: 'วันที่เลือก'),
        if (widget.openDates != null)
          const Text(
            'วันที่เป็นสีเทา = ยังไม่เปิดรับการจอง',
            style: TextStyle(fontSize: 12, color: AppColors.chipFullText),
          ),
      ],
    );
  }

  Widget _legendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textDark),
        ),
      ],
    );
  }
}
