import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/booking_model.dart';
import '../utils/app_api.dart';
import '../widgets/booking_list_widget.dart';
import 'booking_screen.dart';

/// หน้ารายการจองของผู้ใช้ กดปุ่มแก้ไขเพื่อไปหน้าแก้ไข หรือกด + เพื่อจองใหม่
class BookingListScreen extends StatefulWidget {
  const BookingListScreen({super.key});

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen> {
  List<BookingModel> store = [];
  bool _isLoading = true;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      var response = await AppAPI.get("/bookings/list");
      Map<String, dynamic> json = jsonDecode(response.body);
      BookingResponse bookingResponse = BookingResponse.fromJson(json);

      if (!mounted) return;
      setState(() {
        store = bookingResponse.data;
        _errorMessage = bookingResponse.isError ? bookingResponse.errorMessage : "";
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้";
        _isLoading = false;
      });
    }
  }

  // เปิดหน้า BookingScreen (bookingId = 0 คือจองใหม่) แล้ว load ข้อมูลใหม่ทุกครั้งที่กลับมา
  Future<void> _openBooking(int bookingId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(bookingId: bookingId),
      ),
    );

    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.cardPink,
        onPressed: () => _openBooking(0),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                      'การจองของฉัน',
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
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    return BookingListWidget(
      bookingModelStore: store,
      onEditPressed: _openBooking,
    );
  }
}
