import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:my_app/screen/booking_calendar_screen.dart';
import 'package:my_app/screen/document/document_list_screen.dart';

import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../utils/app_api.dart';
import '../../widgets/menu_card__widget.dart';
import '../../widgets/navbar.dart';
import '../booking_list_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _user = {};
  String? _bookingLocation; // สถานที่ยื่นเอกสารของวันที่เปิดรับใกล้ที่สุด

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadBookingLocation();
  }

  // ดึงสถานที่ยื่นเอกสารจากวันที่เปิดรับการจองที่ใกล้ที่สุด ใช้แสดงในการ์ด "การจอง"
  Future<void> _loadBookingLocation() async {
    try {
      final response = await AppAPI.get('/bookings/open-days');
      final json = jsonDecode(response.body);

      if (!mounted || json['isError'] == true || json['data'] is! List) return;

      final days = json['data'] as List;
      final String location = days.isEmpty
          ? ''
          : (days.first['location'] ?? '').toString().trim();

      setState(() => _bookingLocation = location.isEmpty ? null : location);
    } catch (e) {
      // โหลดไม่ได้ก็แสดงการ์ดโดยไม่มีสถานที่
    }
  }

  // silent = true: โหลดใหม่เงียบๆ ไม่โชว์ loading (ใช้ตอนกลับจากหน้าโปรไฟล์)
  Future<void> _loadProfile({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final response = await AppAPI.get('/profile');

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final result = jsonDecode(response.body);

      if (result['isError'] == true) {
        throw Exception(result['errorMessage'] ?? 'ไม่สามารถโหลดข้อมูลได้');
      }

      final data = result['data'];

      if (data is List && data.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          _user = Map<String, dynamic>.from(data[0]);
          _isLoading = false;
          _errorMessage = '';
        });
      } else {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'ไม่สามารถโหลดข้อมูลโปรไฟล์ได้';
      });
    }
  }

  // ==================================================
  // Helpers
  // ==================================================

  String _value(String key) {
    final value = _user[key];

    if (value == null || value.toString().trim().isEmpty) {
      return '-';
    }

    return value.toString();
  }

  String _fullName() {
    final prefix = _user['prefix']?.toString() ?? '';
    final firstName = _user['first_name']?.toString() ?? '';
    final lastName = _user['last_name']?.toString() ?? '';

    final name = '$prefix$firstName $lastName'.trim();

    return name.isEmpty ? 'นักศึกษา' : name;
  }

  String? _profileImageUrl() {
    final image = _user['profile_image'];

    if (image == null || image.toString().trim().isEmpty) {
      return null;
    }

    return '${AppConfig.serverUrl}${image.toString()}';
  }

  // ==================================================
  // Navigation
  // ==================================================

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );

    // กลับมาแล้วโหลดใหม่ เผื่อเปลี่ยนรูป/แก้ข้อมูลในหน้าโปรไฟล์
    if (mounted) {
      _loadProfile(silent: true);
    }
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        break;

      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DocumentListScreen()),
        );
        break;

      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BookingCalendarScreen(),
          ),
        );
        break;

      case 3:
        _openProfile();
        break;
    }
  }

  // ==================================================
  // UI pieces
  // ==================================================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color.fromRGBO(120, 90, 160, 0.15),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  Widget _avatar() {
    final imageUrl = _profileImageUrl();

    final fallback = Container(
      color: const Color(0xffffeaf5),
      child: const Icon(
        Icons.person_rounded,
        size: 42,
        color: Color(0xffa875b7),
      ),
    );

    return GestureDetector(
      onTap: _openProfile,
      child: Container(
        width: 82,
        height: 82,
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFFF8FD8), Color(0xFFC98CFF)],
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          padding: const EdgeInsets.all(2),
          child: ClipOval(
            child: imageUrl == null
                ? fallback
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => fallback,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xffeba6d0)),
              ),
            )
          : _errorMessage.isNotEmpty
          ? Column(
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 42,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                TextButton(
                  onPressed: _loadProfile,
                  child: const Text('ลองใหม่'),
                ),
              ],
            )
          : Row(
              children: [
                _avatar(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'สวัสดี 👋',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xff8b6fa3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fullName(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffffeaf5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'รหัส ${_value('student_code')}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xffa875b7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 21, color: AppColors.iconPurple),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xfffff1f8),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: const Color(0xffb47aaa)),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ข้อมูลการศึกษา',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          _infoRow(
            Icons.badge_outlined,
            'รหัสนักศึกษา',
            _value('student_code'),
          ),
          _infoRow(Icons.account_balance_outlined, 'คณะ', _value('faculty')),
          _infoRow(Icons.menu_book_outlined, 'สาขา', _value('major')),
        ],
      ),
    );
  }

  // ==================================================
  // Build
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final loaded = !_isLoading && _errorMessage.isEmpty;

    return Scaffold(
      extendBody: true,
      bottomNavigationBar: CustomNavBar(currentIndex: 0, onTap: _onNavTap),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xfff8d7f3), Color(0xffeef2ff), Colors.white],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: const Color(0xff8B6FA3),
            onRefresh: () => _loadProfile(silent: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 110),
              children: [
                _headerCard(),

                if (loaded) ...[
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      _statTile(
                        Icons.school_outlined,
                        'ชั้นปี',
                        'ปี ${_value('year')}',
                        AppColors.cardPurple,
                      ),
                      const SizedBox(width: 12),
                      _statTile(
                        Icons.grade_outlined,
                        'GPA',
                        _value('GPA'),
                        AppColors.cardPink,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _infoCard(),
                ],

                // ==================================================
                // ช่อง dashboard ของเพื่อนในกลุ่ม (เพิ่ม widget ตรงนี้)
                // const SizedBox(height: 16),
                // BookingSummaryCard(),
                // ==================================================
                const SizedBox(height: 22),

                MenuCard(
                  title: 'ยื่นเอกสาร',
                  subtitle: 'ส่งเอกสารประกอบการกู้ยืม และตรวจสอบสถานะเอกสาร',
                  titleSize: 22,
                  leadingIcon: Icons.description,
                  color: const Color(0xffffeef8),
                  buttonLabel: 'ยื่นเอกสาร',
                  buttonIcon: Icons.upload_file,
                  onButtonTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DocumentListScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 22),

                MenuCard(
                  title: 'การจอง',
                  subtitle: 'จองคิวเพื่อนำเอกสารกู้ยืม กยศ. ไปยื่น',
                  titleSize: 22,
                  leadingIcon: Icons.calendar_month_rounded,
                  status: _bookingLocation == null
                      ? null
                      : 'สถานที่: $_bookingLocation',
                  statusIcon: Icons.location_on_outlined,
                  color: const Color(0xfff6cde3),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BookingListScreen(),
                      ),
                    );

                    _loadBookingLocation();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}