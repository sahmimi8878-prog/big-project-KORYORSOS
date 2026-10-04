import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import 'booking_rounds_screen.dart';
import 'booking_view_screen.dart';

/// หน้าจัดการระบบการจองของเจ้าหน้าที่ รวมเป็นหน้าเดียว แบ่งเป็น 2 แท็บ:
/// แสดงข้อมูลการจอง / แก้ไขข้อมูลการจอง (ปุ่ม + ในแท็บนี้ใช้เพิ่มข้อมูลการจอง)
class BookingManageScreen extends StatefulWidget {
  const BookingManageScreen({super.key});

  @override
  State<BookingManageScreen> createState() => _BookingManageScreenState();
}

class _BookingManageScreenState extends State<BookingManageScreen>
    with SingleTickerProviderStateMixin {
  static const List<({IconData icon, String label})> _tabs = [
    (icon: Icons.event_note_rounded, label: 'แสดงข้อมูลการจอง'),
    (icon: Icons.edit_note_rounded, label: 'แก้ไขข้อมูลการจอง'),
  ];

  late final TabController _controller;

  // เปลี่ยนค่าเมื่อเข้าแท็บ เพื่อให้แต่ละแท็บโหลดข้อมูลล่าสุดใหม่
  final List<int> _versions = [0, 0];

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: _tabs.length, vsync: this);
    _controller.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_controller.indexIsChanging) return;

    setState(() => _versions[_controller.index]++);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              // IndexedStack เก็บสถานะของทุกแท็บไว้ ไม่โหลดทิ้งเวลาสลับ
              child: IndexedStack(
                index: _controller.index,
                children: [
                  BookingViewScreen(
                    key: ValueKey('view-${_versions[0]}'),
                    embedded: true,
                  ),
                  BookingRoundsScreen(
                    key: ValueKey('rounds-${_versions[1]}'),
                    embedded: true,
                  ),
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
              'จัดการระบบการจอง',
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

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(5),
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
      child: TabBar(
        controller: _controller,
        onTap: (_) => setState(() {}),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.cardPink,
          borderRadius: BorderRadius.circular(18),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.iconPurple,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        splashBorderRadius: BorderRadius.circular(18),
        tabs: [
          for (final t in _tabs)
            Tab(
              height: 46,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.icon, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(t.label, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
