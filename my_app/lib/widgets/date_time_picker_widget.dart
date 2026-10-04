import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../utils/data_utils.dart';
import 'booking_date_picker_dialog.dart';
import 'time_slot_widget.dart';

/// Widget ลูกสำหรับเลือกวันที่ + ช่วงเวลา (ปุ่มวันที่คู่กับปุ่มเวลา)
/// - กดปุ่มวันที่ : เปิด showDatePicker
/// - กดปุ่มเวลา   : เปิดรายการช่วงเวลา (TimeSlotWidget) ใน bottom sheet
/// - รับค่าปัจจุบันจาก parent และแจ้งค่าที่เลือกใหม่กลับไปผ่าน callback
class DateTimePickerWidget extends StatelessWidget {
  const DateTimePickerWidget({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
    required this.slots,
    required this.onDateChanged,
    required this.onTimeChanged,
    this.bookedDates = const {},
    this.openDates,
  });

  final Set<DateTime>? openDates; // วันที่เปิดรับการจอง (null = เลือกได้ทุกวัน)

  final Set<DateTime> bookedDates; // วันที่ผู้ใช้จองไปแล้ว (แสดงในปฏิทิน)
  final DateTime selectedDate;
  final String? selectedTime;
  final List<Map<String, dynamic>> slots; // {time, remaining, isBreak?}
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String> onTimeChanged;

  Future<void> _pickDate(BuildContext context) async {
    // โหมดแก้ไขอาจเป็นวันที่ผ่านมาแล้ว ต้องให้ firstDate ไม่เกิน initialDate ไม่งั้น picker จะ error
    final DateTime now = DateTime.now();
    final DateTime firstDate = selectedDate.isBefore(now) ? selectedDate : now;

    final DateTime? picked = await showBookingDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: firstDate,
      bookedDates: bookedDates,
      openDates: openDates,
    );

    if (picked != null) {
      onDateChanged(picked);
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'เลือกช่วงเวลา',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 14),
                TimeSlotWidget(
                  selectedTime: selectedTime,
                  slots: slots,
                  onTimeSelected: (newTime) {
                    Navigator.pop(sheetContext); // ปิด bottom sheet
                    onTimeChanged(newTime); // ส่งค่ากลับไปยัง parent
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _pickerButton(
            text: DateUtil.getThaiDate(selectedDate),
            icon: Icons.calendar_today,
            onTap: () => _pickDate(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _pickerButton(
            text: selectedTime ?? 'เลือกช่วงเวลา',
            icon: Icons.access_time,
            onTap: () => _pickTime(context),
            isPlaceholder: selectedTime == null,
          ),
        ),
      ],
    );
  }

  Widget _pickerButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    bool isPlaceholder = false,
  }) {
    return InkWell(
      onTap: onTap,
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
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: isPlaceholder ? Colors.grey : AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(icon, color: AppColors.cardPink, size: 20),
          ],
        ),
      ),
    );
  }
}
