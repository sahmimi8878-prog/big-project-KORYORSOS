import 'package:intl/intl.dart';

class BookingModel {
  final int bookingId;
  final String serviceType;
  final String bookingDate; // รูปแบบ dd-MM-yyyy (จาก DATE_FORMAT ใน backend)
  final String timeSlot;
  final String queueNo;

  BookingModel({
    required this.bookingId,
    required this.serviceType,
    required this.bookingDate,
    required this.timeSlot,
    required this.queueNo,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      bookingId: json['booking_id'] as int,
      serviceType: json['service_type'] as String,
      bookingDate: json['booking_date'] as String,
      timeSlot: json['time_slot'] as String,
      queueNo: (json['queue_no'] ?? '') as String,
    );
  }

  DateTime getBookingDate() {
    return DateFormat('dd-MM-yyyy').parse(bookingDate);
  }
}

class BookingResponse {
  final bool isError;
  final List<BookingModel> data;
  final String errorMessage;

  BookingResponse({
    required this.isError,
    required this.data,
    required this.errorMessage,
  });

  factory BookingResponse.fromJson(Map<String, dynamic> json) {
    // เมื่อ error backend ส่ง data เป็น "" จึงต้องเช็กชนิดก่อน
    final rawData = json['data'];

    return BookingResponse(
      isError: (json['isError'] ?? true) as bool,
      data: rawData is List
          ? rawData
                .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
                .toList()
          : [],
      errorMessage: (json['errorMessage'] ?? '') as String,
    );
  }
}
