import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'add_user_screen.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  List<dynamic> users = [];

  bool isLoading = true;

  // ======================================================
  // ดึง Access Token
  // ======================================================

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('access_token');
  }

  // ======================================================
  // แสดงข้อมูลผู้ใช้
  // ======================================================

  @override
  void initState() {
    super.initState();

    getUsers();
  }

  Future<void> getUsers() async {
    setState(() {
      isLoading = true;
    });

    try {
      final token = await getAccessToken();

      if (token == null || token.isEmpty) {
        setState(() {
          isLoading = false;
        });

        return;
      }

      final response = await http.get(
        Uri.parse('http://127.0.0.1:3000/api/users'),
        headers: {'Authorization': 'Bearer $token'},
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
            users = [];
            isLoading = false;
          });

          _showMessage(result['errorMessage'] ?? 'ไม่สามารถโหลดข้อมูลได้');
        }
      } else if (response.statusCode == 401) {
        setState(() {
          users = [];
          isLoading = false;
        });

        _showMessage('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่');
      } else if (response.statusCode == 403) {
        setState(() {
          users = [];
          isLoading = false;
        });

        _showMessage('ไม่มีสิทธิ์เข้าถึงข้อมูลนี้');
      } else {
        setState(() {
          users = [];
          isLoading = false;
        });

        _showMessage('เกิดข้อผิดพลาดในการโหลดข้อมูล');
      }
    } catch (error) {
      print(error);

      setState(() {
        users = [];
        isLoading = false;
      });

      _showMessage('ไม่สามารถเชื่อมต่อ Server ได้');
    }
  }

  // ======================================================
  // เปิดหน้าเพิ่มผู้ใช้
  // ======================================================

  Future<void> openAddUser() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddUserScreen()),
    );

    getUsers();
  }

  // ======================================================
  // แก้ไขผู้ใช้
  // ======================================================

  Future<void> openEditUser(dynamic user) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddUserScreen(user: user)),
    );

    getUsers();
  }

  // ======================================================
  // ลบผู้ใช้
  // ======================================================

  Future<void> deleteUser(dynamic user) async {
    final userId = user['user_id'];

    final String prefix = user['prefix'] ?? '';
    final String firstName = user['first_name'] ?? '';
    final String lastName = user['last_name'] ?? '';

    final fullName = '$prefix$firstName $lastName'.trim();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'ยืนยันการลบ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'ต้องการลบผู้ใช้\n\n'
            '${fullName.isEmpty ? 'ไม่ระบุชื่อ' : fullName}'
            '\n\nใช่หรือไม่?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('ลบ'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      final token = await getAccessToken();

      if (token == null || token.isEmpty) {
        _showMessage('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่');

        return;
      }

      final response = await http.delete(
        Uri.parse('http://127.0.0.1:3000/api/users/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['isError'] == false) {
        _showMessage('ลบข้อมูลผู้ใช้เรียบร้อยแล้ว');

        getUsers();
      } else if (response.statusCode == 403) {
        _showMessage('ไม่มีสิทธิ์ลบข้อมูลผู้ใช้');
      } else {
        _showMessage(result['errorMessage'] ?? 'ไม่สามารถลบข้อมูลผู้ใช้ได้');
      }
    } catch (error) {
      print(error);

      _showMessage('ไม่สามารถเชื่อมต่อ Server ได้');
    }
  }

  // ======================================================
  // Message
  // ======================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ======================================================
  // UI
  // ======================================================

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

      floatingActionButton: FloatingActionButton(
        onPressed: openAddUser,
        backgroundColor: const Color(0xffeba6d0),
        foregroundColor: Colors.white,
        elevation: 6,
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
    );
  }

  // ======================================================
  // User Card
  // ======================================================

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
            // ==================================================
            // ชื่อ + Role + ปุ่ม
            // ==================================================
            Row(
              children: [
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
                        'รหัสนักศึกษา: '
                        '${user['student_code'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // Role
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
              ],
            ),

            const SizedBox(height: 12),

            Container(height: 1, color: const Color(0xfff1e8f5)),

            const SizedBox(height: 12),

            // ==================================================
            // Email
            // ==================================================
            _buildInfoRow(Icons.email_outlined, user['email'] ?? '-'),

            const SizedBox(height: 8),

            // ==================================================
            // Phone
            // ==================================================
            _buildInfoRow(Icons.phone_outlined, user['phone'] ?? '-'),

            const SizedBox(height: 8),

            // ==================================================
            // Faculty / Major
            // ==================================================
            _buildInfoRow(
              Icons.school_outlined,
              '${user['faculty'] ?? '-'}'
              ' / '
              '${user['major'] ?? '-'}',
            ),

            const SizedBox(height: 12),

            // ==================================================
            // ปุ่มแก้ไข / ลบ
            // ==================================================
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      openEditUser(user);
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('แก้ไข'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xffb47aaa),
                      side: const BorderSide(color: Color(0xffe8cce3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      deleteUser(user);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('ลบ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Color(0xffffcaca)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // Info Row
  // ======================================================

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

  // ======================================================
  // Empty State
  // ======================================================

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
