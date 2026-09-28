import 'package:flutter/material.dart';
import '../config/app_colors.dart';
 
/// Widget ลูกสำหรับเลือกช่วงเวลา
/// ใช้เทคนิคเดียวกับ DateTimePickerWidget ใน workshop:
/// - รับค่าปัจจุบัน (selectedTime) จาก parent
/// - แจ้งค่าที่ผู้ใช้เลือกใหม่กลับไปยัง parent ผ่าน callback (onTimeSelected)
class TimeSlotWidget extends StatelessWidget {
  final String? selectedTime;
  final List<Map<String, dynamic>> slots; // {time, remaining}
  final ValueChanged<String> onTimeSelected;
 
  const TimeSlotWidget({
    super.key,
    required this.selectedTime,
    required this.slots,
    required this.onTimeSelected,
  });
 
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: slots.map((slot) {
        final String time = slot['time'];
        final int remaining = slot['remaining'];
        final bool isFull = remaining <= 0;
        final bool isSelected = selectedTime == time;
 
        return InkWell(
          onTap: isFull
              ? null
              : () {
                  onTimeSelected(time); // เรียก callback กลับไปยัง BookingScreen
                },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 150,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: isFull
                  ? AppColors.chipFull
                  : (isSelected ? AppColors.cardPink : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.cardPink : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isFull
                        ? AppColors.chipFullText
                        : (isSelected ? Colors.white : AppColors.textDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isFull ? 'เต็ม' : 'เหลือ $remaining คิว',
                  style: TextStyle(
                    fontSize: 12,
                    color: isFull
                        ? AppColors.chipFullText
                        : (isSelected ? Colors.white70 : AppColors.iconPurple),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}