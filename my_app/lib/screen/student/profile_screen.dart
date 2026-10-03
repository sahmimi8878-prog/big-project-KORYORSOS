import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'edit_profile_screen.dart';
import '../../utils/auth_utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? user;
  bool isLoading = true;
  bool isUploading = false;

  final String baseUrl = 'http://127.0.0.1:3000';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final result = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          result['isError'] == false &&
          result['data'] != null &&
          result['data'].isNotEmpty) {
        setState(() {
          user = Map<String, dynamic>.from(result['data'][0]);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });

        _showMessage(result['errorMessage'] ?? 'ไม่สามารถโหลดข้อมูลได้');
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage('เกิดข้อผิดพลาด: $error');
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();

      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        return;
      }

      await _uploadProfileImage(image);
    } catch (error) {
      _showMessage('ไม่สามารถเลือกรูปภาพได้: $error');
    }
  }

  Future<void> _uploadProfileImage(XFile image) async {
    setState(() {
      isUploading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/profile/image'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      final imageBytes = await image.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          'profile_image',
          imageBytes,
          filename: image.name,
        ),
      );

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);

      final result = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && result['isError'] == false) {
        _showMessage('เปลี่ยนรูปโปรไฟล์เรียบร้อยแล้ว');

        await _loadProfile();
      } else {
        _showMessage(result['errorMessage'] ?? 'ไม่สามารถอัปโหลดรูปโปรไฟล์ได้');
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage('เกิดข้อผิดพลาดในการอัปโหลดรูป: $error');
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  Future<void> _editProfile() async {
    if (user == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditProfileScreen(user: user!)),
    );

    if (result == true) {
      await _loadProfile();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _value(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return '-';
    }

    return value.toString();
  }

  String _getFullName() {
    if (user == null) return '';

    final prefix = _value(user!['prefix']);
    final firstName = _value(user!['first_name']);
    final lastName = _value(user!['last_name']);

    return '$prefix $firstName $lastName';
  }

  String? _getProfileImageUrl() {
    if (user == null) return null;

    final image = user!['profile_image'];

    if (image == null || image.toString().trim().isEmpty) {
      return null;
    }

    return '$baseUrl${image.toString()}';
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xffffeef8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xff9a70b4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xff5b4568),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    final imageUrl = _getProfileImageUrl();

    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xffe89bc9), width: 4),
          ),
          child: ClipOval(
            child: imageUrl == null
                ? Container(
                    color: const Color(0xffffeef8),
                    child: const Icon(
                      Icons.person,
                      size: 65,
                      color: Color(0xff9a70b4),
                    ),
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xffffeef8),
                        child: const Icon(
                          Icons.person,
                          size: 65,
                          color: Color(0xff9a70b4),
                        ),
                      );
                    },
                  ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: isUploading ? null : _pickProfileImage,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xffe89bc9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.camera_alt, size: 19, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ข้อมูลส่วนตัว')),
        body: Center(
          child: ElevatedButton(
            onPressed: _loadProfile,
            child: const Text('ลองใหม่'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xfff8f2fa),
      appBar: AppBar(
        title: const Text(
          'ข้อมูลส่วนตัว',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff5b4568),
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadProfile, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 25,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    _buildProfileImage(),
                    const SizedBox(height: 15),
                    Text(
                      _getFullName(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff5b4568),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _value(user!['email']),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffffeef8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user!['role_id'] == 1
                            ? 'นักศึกษา'
                            : user!['role_id'] == 2
                            ? 'เจ้าหน้าที่'
                            : 'ไม่ระบุ',
                        style: const TextStyle(
                          color: Color(0xff9a70b4),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'แตะไอคอนกล้องเพื่อเปลี่ยนรูปโปรไฟล์',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ข้อมูลส่วนตัว',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff5b4568),
                      ),
                    ),
                    const SizedBox(height: 18),

                    _buildInfoItem(
                      Icons.email_outlined,
                      'อีเมล',
                      _value(user!['email']),
                    ),

                    _buildInfoItem(
                      Icons.phone_outlined,
                      'เบอร์โทรศัพท์',
                      _value(user!['phone']),
                    ),

                    _buildInfoItem(
                      Icons.credit_card_outlined,
                      'เลขบัตรประชาชน',
                      _value(user!['citizen_id']),
                    ),

                    _buildInfoItem(
                      Icons.cake_outlined,
                      'วันเกิด',
                      _value(user!['birth_date']),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ข้อมูลการศึกษา',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff5b4568),
                      ),
                    ),
                    const SizedBox(height: 18),

                    _buildInfoItem(
                      Icons.badge_outlined,
                      'รหัสนักศึกษา',
                      _value(user!['student_code']),
                    ),

                    _buildInfoItem(
                      Icons.account_balance_outlined,
                      'คณะ',
                      _value(user!['faculty']),
                    ),

                    _buildInfoItem(
                      Icons.menu_book_outlined,
                      'สาขา',
                      _value(user!['major']),
                    ),

                    _buildInfoItem(
                      Icons.school_outlined,
                      'ชั้นปี',
                      _value(user!['year']),
                    ),

                    _buildInfoItem(
                      Icons.star_border,
                      'GPA',
                      _value(user!['GPA']),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _editProfile,
                  icon: const Icon(Icons.edit),
                  label: const Text(
                    'แก้ไขข้อมูลส่วนตัว',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffe89bc9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => AuthUtil.logout(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'ออกจากระบบ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Color(0xffffcaca)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
