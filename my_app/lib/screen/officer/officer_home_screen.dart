import 'package:flutter/material.dart';

import '../../widgets/user_role_chart.dart';
import 'booking/booking_manage_screen.dart';
import 'user/user_screen.dart';
import '../../utils/auth_utils.dart';

class OfficerHomeScreen extends StatefulWidget {
  const OfficerHomeScreen({super.key});

  @override
  State<OfficerHomeScreen> createState() => _OfficerHomeScreenState();
}

class _OfficerHomeScreenState extends State<OfficerHomeScreen> {
  // เปลี่ยนค่านี้เพื่อให้ dashboard โหลดข้อมูลใหม่ (เช่น หลังกลับจากหน้าจัดการผู้ใช้)
  int _reloadKey = 0;

  Future<void> _openUserScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserScreen()),
    );

    setState(() {
      _reloadKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'หน้าหลักเจ้าหน้าที่',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xfff8d7f3),
        foregroundColor: const Color(0xff8B6FA3),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => AuthUtil.logout(context),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'ออกจากระบบ',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xfff8d7f3), Color(0xffeef2ff), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ยินดีต้อนรับ เจ้าหน้าที่ 👋',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff765982),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'ภาพรวมระบบและเมนูจัดการ',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),

                const SizedBox(height: 25),

                // ==================================================
                // Dashboard
                // แต่ละคนทำ widget ของตัวเอง แล้วเพิ่มบรรทัดเดียวตรงนี้
                // ==================================================
                _sectionTitle('ภาพรวมระบบ'),

                const SizedBox(height: 12),

                // ส่วนของเรา: ผู้ใช้
                UserRoleChart(key: ValueKey(_reloadKey)),

                // ส่วนของเพื่อน (เพิ่มตรงนี้)
                // const SizedBox(height: 16),
                // DocumentSummaryCard(),
                // const SizedBox(height: 16),
                // BookingSummaryCard(),
                const SizedBox(height: 28),

                // ==================================================
                // เมนูจัดการ
                // ==================================================
                _sectionTitle('เมนูจัดการ'),

                const SizedBox(height: 12),

                _buildMenuCard(
                  context,
                  icon: Icons.people_rounded,
                  title: 'จัดการข้อมูลผู้ใช้',
                  subtitle: 'แสดง เพิ่ม แก้ไข และลบข้อมูลผู้ใช้',
                  onTap: _openUserScreen,
                ),

                const SizedBox(height: 16),

                _buildMenuCard(
                  context,
                  icon: Icons.description_rounded,
                  title: 'จัดการเอกสาร',
                  subtitle: 'แสดง เพิ่ม แก้ไข และจัดการเอกสาร',
                  onTap: () {
                    // เดี๋ยวเชื่อมหน้าเอกสารตรงนี้
                  },
                ),

                const SizedBox(height: 16),

                _buildMenuCard(
                  context,
                  icon: Icons.event_note_rounded,
                  title: 'จัดการระบบการจอง',
                  subtitle: 'แสดง แก้ไข และลบรายการจองของนักศึกษา',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BookingManageScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Color(0xff8B6FA3),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
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
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xffffe5f4),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 30, color: const Color(0xffb47aaa)),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff765982),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Color(0xffb47aaa),
            ),
          ],
        ),
      ),
    );
  }
}
