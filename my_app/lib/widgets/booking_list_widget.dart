import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/booking_model.dart';
import '../utils/data_utils.dart';

/// แสดงรายการจองด้วย ListTile (leading / title / subtitle / trailing)
/// ปุ่มแก้ไขส่ง bookingId กลับไปยัง parent ผ่าน callback (onEditPressed)
class BookingListWidget extends StatelessWidget {
  const BookingListWidget({
    super.key,
    required this.bookingModelStore,
    required this.onEditPressed,
  });

  final List<BookingModel> bookingModelStore;
  final Function(int) onEditPressed;

  @override
  Widget build(BuildContext context) {
    if (bookingModelStore.isEmpty) {
      return const Center(
        child: Text(
          'ยังไม่มีรายการจอง',
          style: TextStyle(color: AppColors.iconPurple),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: bookingModelStore.length,
      itemBuilder: (context, index) {
        BookingModel item = bookingModelStore[index];

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            leading: const Icon(
              Icons.event_available,
              color: AppColors.cardPink,
            ),
            title: Text(
              '${DateUtil.getThaiDate(item.getBookingDate())}  ${item.timeSlot}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Text('${item.queueNo}  ${item.serviceType}'),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              color: Colors.redAccent,
              splashColor: Colors.red.withValues(alpha: 0.1),
              onPressed: () {
                onEditPressed(item.bookingId);
              },
            ),
          ),
        );
      },
    );
  }
}
