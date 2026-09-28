import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'add_user_screen.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  List<dynamic> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getUsers();
  }

  // ดึงข้อมูลผู้ใช้จาก Backend
  Future<void> getUsers() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:3000/api/users'),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['isError'] == false) {
          setState(() {
            users = result['data'];
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (error) {
      print(error);

      setState(() {
        isLoading = false;
      });
    }
  }

  // เปิดหน้าเพิ่มผู้ใช้
  Future<void> openAddUser() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddUserScreen()),
    );

    // กลับมาจากหน้าเพิ่มแล้วโหลดข้อมูลใหม่
    getUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ข้อมูลผู้ใช้ 🌸',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xfff8d7f3),
        foregroundColor: const Color(0xff8B6FA3),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: getUsers,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'รีเฟรช',
          ),
          IconButton(
            onPressed: openAddUser,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'เพิ่มผู้ใช้',
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
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xffeba6d0)),
                )
              : users.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xff8B6FA3),
                  onRefresh: getUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];

                      return _buildUserCard(user);
                    },
                  ),
                ),
        ),
      ),

      // ปุ่ม + ด้านล่าง
      floatingActionButton: FloatingActionButton(
        onPressed: openAddUser,
        backgroundColor: const Color(0xffeba6d0),
        foregroundColor: Colors.white,
        elevation: 6,
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
    );
  }

  // Card ผู้ใช้
  Widget _buildUserCard(dynamic user) {
    final String prefix = user['prefix'] ?? '';
    final String firstName = user['first_name'] ?? '';
    final String lastName = user['last_name'] ?? '';

    final String fullName = '$prefix$firstName $lastName'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(120, 90, 160, 0.20),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ส่วนบนของ Card
            Row(
              children: [
                // รูป/ไอคอนผู้ใช้
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xffffe5f4),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 32,
                    color: Color(0xffb47aaa),
                  ),
                ),

                const SizedBox(width: 14),

                // ชื่อ
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isEmpty ? 'ไม่ระบุชื่อ' : fullName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff765982),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'รหัสนักศึกษา: ${user['student_code'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // Role
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffeef2ff),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user['role_id'] == 1
                            ? 'นักศึกษา'
                            : user['role_id'] == 2
                            ? 'เจ้าหน้าที่'
                            : 'ไม่ระบุ',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff8B6FA3),
                        ),
                      ),
                    ),

                    const SizedBox(width: 5),

                    IconButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddUserScreen(user: user),
                          ),
                        );

                        // กลับมาหน้านี้แล้วโหลดข้อมูลใหม่
                        getUsers();
                      },
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: Color(0xffb47aaa),
                      ),
                      tooltip: 'แก้ไข',
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // เส้นคั่น
            Container(height: 1, color: const Color(0xfff1e8f5)),

            const SizedBox(height: 12),

            // Email
            _buildInfoRow(Icons.email_outlined, user['email'] ?? '-'),

            const SizedBox(height: 8),

            // เบอร์โทร
            _buildInfoRow(Icons.phone_outlined, user['phone'] ?? '-'),

            const SizedBox(height: 8),

            // คณะ / สาขา
            _buildInfoRow(
              Icons.school_outlined,
              '${user['faculty'] ?? '-'} / ${user['major'] ?? '-'}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xfffff1f8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: const Color(0xffb47aaa)),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xff6f6872)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // กรณีไม่มีข้อมูล
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xffffe5f4),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 55,
                color: Color(0xffc18ab5),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'ยังไม่มีข้อมูลผู้ใช้ 🥺',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xff765982),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'กดปุ่ม + เพื่อเพิ่มผู้ใช้คนแรก',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: openAddUser,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('เพิ่มผู้ใช้'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffeba6d0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
