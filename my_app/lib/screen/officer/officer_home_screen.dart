import 'package:flutter/material.dart';
import 'user/user_screen.dart';
import 'document/officer_document_screen.dart';

class OfficerHomeScreen extends StatelessWidget {
  const OfficerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'หน้าหลักเจ้าหน้าที่',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xfff8d7f3),
        foregroundColor: const Color(0xff8B6FA3),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xfff8d7f3),
              Color(0xffeef2ff),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
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
                  'เลือกเมนูที่ต้องการดำเนินการ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 25),

                // จัดการข้อมูลผู้ใช้
                _buildMenuCard(
                  context,
                  icon: Icons.people_rounded,
                  title: 'จัดการข้อมูลผู้ใช้',
                  subtitle: 'แสดง เพิ่ม และแก้ไขข้อมูลผู้ใช้',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // จัดการเอกสาร
                _buildMenuCard(
                  context,
                  icon: Icons.description_rounded,
                  title: 'จัดการเอกสาร',
                  subtitle: 'แสดง เพิ่ม แก้ไข และจัดการเอกสาร',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OfficerDocumentScreen()),
                    );
                    // เดี๋ยวเชื่อมหน้าเอกสารตรงนี้
                  },
                ),
              ],
            ),
          ),
        ),
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
              child: Icon(
                icon,
                size: 30,
                color: const Color(0xffb47aaa),
              ),
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
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