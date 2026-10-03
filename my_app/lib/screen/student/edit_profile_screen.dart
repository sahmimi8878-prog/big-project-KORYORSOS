import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends State<EditProfileScreen> {

  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _studentCodeController;
  late TextEditingController _facultyController;
  late TextEditingController _majorController;
  late TextEditingController _gpaController;

  late String _selectedPrefix;

  int? _selectedYear;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final user = widget.user;

    _firstNameController =
        TextEditingController(
      text: user['first_name']?.toString() ?? '',
    );

    _lastNameController =
        TextEditingController(
      text: user['last_name']?.toString() ?? '',
    );

    _phoneController =
        TextEditingController(
      text: user['phone']?.toString() ?? '',
    );

    _studentCodeController =
        TextEditingController(
      text: user['student_code']?.toString() ?? '',
    );

    _facultyController =
        TextEditingController(
      text: user['faculty']?.toString() ?? '',
    );

    _majorController =
        TextEditingController(
      text: user['major']?.toString() ?? '',
    );

    _gpaController =
        TextEditingController(
      text: user['GPA']?.toString() ?? '',
    );

    _selectedPrefix =
        user['prefix']?.toString() ?? 'นาย';

    _selectedYear =
        int.tryParse(
      user['year']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _studentCodeController.dispose();
    _facultyController.dispose();
    _majorController.dispose();
    _gpaController.dispose();

    super.dispose();
  }

  // ==================================================
  // Token
  // ==================================================

  Future<String?> _getToken() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getString('access_token');
  }

  // ==================================================
  // Save
  // ==================================================

  Future<void> _saveProfile() async {

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {

      final token = await _getToken();

      if (token == null || token.isEmpty) {
        _showMessage(
          'กรุณาเข้าสู่ระบบใหม่',
        );
        return;
      }

      final data = {
        'prefix': _selectedPrefix,

        'first_name':
            _firstNameController.text.trim(),

        'last_name':
            _lastNameController.text.trim(),

        'student_code':
            _studentCodeController.text.trim(),

        'phone':
            _phoneController.text.trim(),

        'faculty':
            _facultyController.text.trim(),

        'major':
            _majorController.text.trim(),

        'year':
            _selectedYear,

        'gpa':
            double.tryParse(
          _gpaController.text.trim(),
        ),
      };

      final response = await http.put(
        Uri.parse(
          'http://127.0.0.1:3000/api/profile',
        ),

        headers: {
          'Authorization':
              'Bearer $token',

          'Content-Type':
              'application/json',
        },

        body: jsonEncode(data),
      );

      final result =
          jsonDecode(response.body);

      if (response.statusCode == 200 &&
          result['isError'] == false) {

        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'บันทึกข้อมูลส่วนตัวเรียบร้อยแล้ว',
            ),
            behavior:
                SnackBarBehavior.floating,
          ),
        );

        Navigator.pop(context, true);

      } else {

        _showMessage(
          result['errorMessage'] ??
              'ไม่สามารถบันทึกข้อมูลได้',
        );
      }

    } catch (e) {

      _showMessage(
        'ไม่สามารถเชื่อมต่อ Server ได้',
      );

    } finally {

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ==================================================
  // Message
  // ==================================================

  void _showMessage(String message) {

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor:
          const Color(0xffF8F5FA),

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor:
            const Color(0xff493752),
        elevation: 0,

        title: const Text(
          'แก้ไขข้อมูลส่วนตัว',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Form(
        key: _formKey,

        child: ListView(
          padding: const EdgeInsets.all(18),

          children: [

            // =========================
            // ข้อมูลพื้นฐาน
            // =========================

            _buildSection(
              'ข้อมูลพื้นฐาน',

              [
                _buildPrefixField(),

                const SizedBox(height: 12),

                _buildTextField(
                  controller:
                      _firstNameController,
                  label: 'ชื่อ',
                  icon:
                      Icons.person_outline_rounded,
                ),

                const SizedBox(height: 12),

                _buildTextField(
                  controller:
                      _lastNameController,
                  label: 'นามสกุล',
                  icon:
                      Icons.person_outline_rounded,
                ),

                const SizedBox(height: 12),

                _buildTextField(
                  controller:
                      _phoneController,
                  label: 'เบอร์โทรศัพท์',
                  icon:
                      Icons.phone_outlined,
                  keyboardType:
                      TextInputType.phone,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // =========================
            // ข้อมูลการศึกษา
            // =========================

            _buildSection(
              'ข้อมูลการศึกษา',

              [
                _buildTextField(
                  controller:
                      _studentCodeController,
                  label: 'รหัสนักศึกษา',
                  icon:
                      Icons.badge_outlined,
                  keyboardType:
                      TextInputType.number,
                ),

                const SizedBox(height: 12),

                _buildTextField(
                  controller:
                      _facultyController,
                  label: 'คณะ',
                  icon:
                      Icons.account_balance_outlined,
                ),

                const SizedBox(height: 12),

                _buildTextField(
                  controller:
                      _majorController,
                  label: 'สาขา',
                  icon:
                      Icons.menu_book_outlined,
                ),

                const SizedBox(height: 12),

                Row(
                  children: [

                    Expanded(
                      child:
                          _buildYearField(),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child:
                          _buildTextField(
                        controller:
                            _gpaController,
                        label: 'GPA',
                        icon:
                            Icons.grade_outlined,
                        keyboardType:
                            const TextInputType
                                .numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 22),

            // =========================
            // ปุ่มบันทึก
            // =========================

            SizedBox(
              height: 54,

              child: ElevatedButton(

                onPressed:
                    _isSaving
                        ? null
                        : _saveProfile,

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xffEBA6D0,
                  ),

                  foregroundColor:
                      Colors.white,

                  elevation: 4,

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      17,
                    ),
                  ),
                ),

                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,

                        child:
                            CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'บันทึกการเปลี่ยนแปลง',

                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================
  // Section
  // ==================================================

  Widget _buildSection(
    String title,
    List<Widget> children,
  ) {

    return Container(

      padding:
          const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(22),

        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(
              80,
              60,
              90,
              0.06,
            ),

            blurRadius: 12,

            offset:
                Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Text(
            title,

            style: const TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
              color:
                  Color(0xff493752),
            ),
          ),

          const SizedBox(height: 14),

          ...children,
        ],
      ),
    );
  }

  // ==================================================
  // Text Field
  // ==================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {

    return TextFormField(

      controller: controller,

      keyboardType:
          keyboardType,

      validator: (value) {

        if (value == null ||
            value.trim().isEmpty) {

          return 'กรุณากรอก$label';
        }

        return null;
      },

      decoration:
          InputDecoration(

        labelText: label,

        prefixIcon:
            Icon(
          icon,
          color:
              const Color(
            0xff8B6FA3,
          ),
        ),

        filled: true,

        fillColor:
            const Color(
          0xffFAF7FC,
        ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          borderSide:
              BorderSide.none,
        ),
      ),
    );
  }

  // ==================================================
  // Prefix
  // ==================================================

  Widget _buildPrefixField() {

    return DropdownButtonFormField<String>(

      value:
          _selectedPrefix,

      decoration:
          InputDecoration(
        labelText:
            'คำนำหน้า',

        prefixIcon:
            const Icon(
          Icons.badge_outlined,
          color:
              Color(0xff8B6FA3),
        ),

        filled: true,

        fillColor:
            const Color(
          0xffFAF7FC,
        ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          borderSide:
              BorderSide.none,
        ),
      ),

      items: const [

        DropdownMenuItem(
          value: 'นาย',
          child: Text('นาย'),
        ),

        DropdownMenuItem(
          value: 'นาง',
          child: Text('นาง'),
        ),

        DropdownMenuItem(
          value: 'นางสาว',
          child: Text('นางสาว'),
        ),
      ],

      onChanged: (value) {

        if (value != null) {

          setState(() {
            _selectedPrefix = value;
          });
        }
      },
    );
  }

  // ==================================================
  // Year
  // ==================================================

  Widget _buildYearField() {

    return DropdownButtonFormField<int>(

      value:
          _selectedYear,

      decoration:
          InputDecoration(
        labelText:
            'ชั้นปี',

        prefixIcon:
            const Icon(
          Icons.school_outlined,
          color:
              Color(0xff8B6FA3),
        ),

        filled: true,

        fillColor:
            const Color(
          0xffFAF7FC,
        ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          borderSide:
              BorderSide.none,
        ),
      ),

      items: const [

        DropdownMenuItem(
          value: 1,
          child: Text('ปี 1'),
        ),

        DropdownMenuItem(
          value: 2,
          child: Text('ปี 2'),
        ),

        DropdownMenuItem(
          value: 3,
          child: Text('ปี 3'),
        ),

        DropdownMenuItem(
          value: 4,
          child: Text('ปี 4'),
        ),
      ],

      onChanged: (value) {

        setState(() {
          _selectedYear = value;
        });
      },
    );
  }
}