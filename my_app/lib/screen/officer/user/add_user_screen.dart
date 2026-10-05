import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AddUserScreen extends StatefulWidget {
  // ถ้าเป็น null = เพิ่มผู้ใช้
  // ถ้ามีข้อมูล = แก้ไขผู้ใช้
  final Map<String, dynamic>? user;

  const AddUserScreen({super.key, this.user});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _studentCodeController = TextEditingController();
  final _citizenIdController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _facultyController = TextEditingController();
  final _majorController = TextEditingController();
  final _gpaController = TextEditingController();

  DateTime? _birthDate;
  int? _selectedYear;
  String? _selectedPrefix;

  // role: 1 = นักศึกษา, 2 = เจ้าหน้าที่
  int _selectedRole = 1;

  bool _isLoading = false;

  // true เมื่อเปิดหน้านี้เพื่อแก้ไข
  bool get isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();

    // ถ้าเป็นหน้าแก้ไข ให้เอาข้อมูลเดิมมาใส่ในช่อง
    if (isEdit) {
      _loadUserData();
    }
  }

  void _loadUserData() {
    final user = widget.user!;

    _emailController.text = user['email']?.toString() ?? '';

    _studentCodeController.text = user['student_code']?.toString() ?? '';

    _citizenIdController.text = user['citizen_id']?.toString() ?? '';

    _selectedPrefix = user['prefix']?.toString();

    _firstNameController.text = user['first_name']?.toString() ?? '';

    _lastNameController.text = user['last_name']?.toString() ?? '';

    _phoneController.text = user['phone']?.toString() ?? '';

    _facultyController.text = user['faculty']?.toString() ?? '';

    _majorController.text = user['major']?.toString() ?? '';

    // year อาจมาเป็น int หรือ String
    _selectedYear = int.tryParse(user['year']?.toString() ?? '');

    // role
    _selectedRole = int.tryParse(user['role_id']?.toString() ?? '') ?? 1;

    // GPA
    final gpa = user['GPA'] ?? user['gpa'];

    if (gpa != null) {
      _gpaController.text = gpa.toString();
    }

    // วันเกิด
    if (user['birth_date'] != null) {
      _birthDate = DateTime.tryParse(user['birth_date'].toString());
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _studentCodeController.dispose();
    _citizenIdController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _facultyController.dispose();
    _majorController.dispose();
    _gpaController.dispose();

    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: "เลือกวันเกิด",
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');

    return "$y-$m-$d";
  }

  // =========================================================
  // เพิ่ม / แก้ไข
  // =========================================================

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_birthDate == null) {
      _showMessage("กรุณาเลือกวันเกิดด้วยนะ");
      return;
    }

    if (_selectedYear == null) {
      _showMessage("กรุณาเลือกชั้นปีด้วยนะ");
      return;
    }

    if (_selectedPrefix == null) {
      _showMessage("กรุณาเลือกคำนำหน้าด้วยนะ");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // ข้อมูลที่ใช้ทั้งเพิ่มและแก้ไข
    final Map<String, dynamic> data = {
      "email": _emailController.text.trim(),
      "student_code": _studentCodeController.text.trim(),
      "citizen_id": _citizenIdController.text.trim(),
      "prefix": _selectedPrefix,
      "first_name": _firstNameController.text.trim(),
      "last_name": _lastNameController.text.trim(),
      "birth_date": _formatDate(_birthDate!),
      "phone": _phoneController.text.trim(),
      "faculty": _facultyController.text.trim(),
      "major": _majorController.text.trim(),
      "year": _selectedYear,
      "gpa": double.tryParse(_gpaController.text.trim()),
      "role_id": _selectedRole,
    };

    // ถ้าเพิ่มผู้ใช้ ต้องส่ง password ด้วย
    if (!isEdit) {
      data["password"] = _passwordController.text;
    }

    try {
      // ดึง token (ทุก endpoint ของ /api/users ต้องใช้ token เจ้าหน้าที่)
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        _showMessage("Session หมดอายุ กรุณาเข้าสู่ระบบใหม่");
        return;
      }

      final headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      };

      late http.Response response;

      if (isEdit) {
        // ==========================================
        // แก้ไข
        // ==========================================

        final userId = widget.user!['user_id'];

        response = await http.put(
          Uri.parse('http://127.0.0.1:3000/api/users/$userId'),
          headers: headers,
          body: jsonEncode(data),
        );
      } else {
        // ==========================================
        // เพิ่ม
        // ==========================================

        response = await http.post(
          Uri.parse('http://127.0.0.1:3000/api/users'),
          headers: headers,
          body: jsonEncode(data),
        );
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      final json = jsonDecode(response.body);

      final bool isError = json["isError"] ?? true;

      if (!isError) {
        _showMessage(
          isEdit ? "แก้ไขข้อมูลผู้ใช้สำเร็จ ✨" : "เพิ่มผู้ใช้สำเร็จ ✨",
        );

        await Future.delayed(const Duration(milliseconds: 800));

        if (!mounted) return;

        Navigator.pop(context);
      } else {
        _showMessage(
          json["errorMessage"] ??
              (isEdit ? "แก้ไขข้อมูลไม่สำเร็จ" : "เพิ่มผู้ใช้ไม่สำเร็จ"),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      print(e);

      _showMessage("เชื่อมต่อ server ไม่ได้");
    }
  }

  // =========================================================
  // SnackBar
  // =========================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xff8B6FA3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "กรุณากรอกข้อมูลนี้";
    }

    return null;
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xffeba6d0),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        counterText: "",
        prefixIcon: Icon(icon, color: const Color(0xff8B6FA3), size: 20),
        filled: true,
        fillColor: const Color(0xffeef2ff),
        labelStyle: const TextStyle(color: Color(0xff8B6FA3), fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffeba6d0), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "แก้ไขข้อมูลผู้ใช้" : "เพิ่มข้อมูลผู้ใช้"),
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(120, 90, 160, 0.28),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // =================================================
                        // บัญชีผู้ใช้
                        // =================================================
                        _sectionTitle("บัญชีผู้ใช้"),

                        const SizedBox(height: 12),

                        _buildTextField(
                          controller: _emailController,
                          label: "อีเมล",
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "กรุณากรอกอีเมล";
                            }

                            if (!value.contains("@")) {
                              return "รูปแบบอีเมลไม่ถูกต้อง";
                            }

                            return null;
                          },
                        ),

                        // ตอนแก้ไขไม่ต้องกรอกรหัสผ่าน
                        if (!isEdit) ...[
                          const SizedBox(height: 14),

                          _buildTextField(
                            controller: _passwordController,
                            label: "รหัสผ่าน",
                            icon: Icons.lock_outline,
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "กรุณากรอกรหัสผ่าน";
                              }

                              if (value.length < 6) {
                                return "รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร";
                              }

                              return null;
                            },
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Role
                        DropdownButtonFormField<int>(
                          value: _selectedRole,
                          decoration: InputDecoration(
                            labelText: "Role",
                            prefixIcon: const Icon(
                              Icons.admin_panel_settings_outlined,
                              color: Color(0xff8B6FA3),
                            ),
                            filled: true,
                            fillColor: const Color(0xffeef2ff),
                            labelStyle: const TextStyle(
                              color: Color(0xff8B6FA3),
                              fontSize: 13,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text("นักศึกษา")),
                            DropdownMenuItem(
                              value: 2,
                              child: Text("เจ้าหน้าที่"),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value ?? 1;
                            });
                          },
                        ),

                        const SizedBox(height: 22),

                        // =================================================
                        // ข้อมูลส่วนตัว / ข้อมูลนักศึกษา
                        // =================================================
                        _sectionTitle("ข้อมูลนักศึกษา"),

                        const SizedBox(height: 12),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: _selectedPrefix,
                                decoration: InputDecoration(
                                  labelText: "คำนำหน้า",
                                  filled: true,
                                  fillColor: const Color(0xffeef2ff),
                                  labelStyle: const TextStyle(
                                    color: Color(0xff8B6FA3),
                                    fontSize: 13,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: const ["นาย", "นาง", "นางสาว"]
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(p),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedPrefix = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return "เลือกคำนำหน้า";
                                  }

                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              flex: 3,
                              child: _buildTextField(
                                controller: _firstNameController,
                                label: "ชื่อ",
                                icon: Icons.badge_outlined,
                                validator: _requiredValidator,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        _buildTextField(
                          controller: _lastNameController,
                          label: "นามสกุล",
                          icon: Icons.badge_outlined,
                          validator: _requiredValidator,
                        ),

                        const SizedBox(height: 14),

                        _buildTextField(
                          controller: _studentCodeController,
                          label: "รหัสนักศึกษา",
                          icon: Icons.numbers_outlined,
                          keyboardType: TextInputType.number,
                          validator: _requiredValidator,
                        ),

                        const SizedBox(height: 14),

                        _buildTextField(
                          controller: _citizenIdController,
                          label: "เลขบัตรประชาชน",
                          icon: Icons.credit_card_outlined,
                          keyboardType: TextInputType.number,
                          maxLength: 13,
                          validator: _requiredValidator,
                        ),

                        const SizedBox(height: 6),

                        // วันเกิด
                        InkWell(
                          onTap: _pickBirthDate,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffeef2ff),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xffe0d4f7),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.cake_outlined,
                                  color: Color(0xff8B6FA3),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _birthDate == null
                                      ? "เลือกวันเกิด"
                                      : _formatDate(_birthDate!),
                                  style: TextStyle(
                                    color: _birthDate == null
                                        ? Colors.grey
                                        : Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        _buildTextField(
                          controller: _phoneController,
                          label: "เบอร์โทรศัพท์",
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: _requiredValidator,
                        ),

                        const SizedBox(height: 14),

                        _buildTextField(
                          controller: _facultyController,
                          label: "คณะ",
                          icon: Icons.school_outlined,
                          validator: _requiredValidator,
                        ),

                        const SizedBox(height: 14),

                        _buildTextField(
                          controller: _majorController,
                          label: "สาขา",
                          icon: Icons.menu_book_outlined,
                          validator: _requiredValidator,
                        ),

                        const SizedBox(height: 14),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedYear,
                                decoration: InputDecoration(
                                  labelText: "ชั้นปี",
                                  filled: true,
                                  fillColor: const Color(0xffeef2ff),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: const [1, 2, 3, 4]
                                    .map(
                                      (y) => DropdownMenuItem(
                                        value: y,
                                        child: Text("ปี $y"),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedYear = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return "เลือกชั้นปี";
                                  }

                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: _buildTextField(
                                controller: _gpaController,
                                label: "GPA",
                                icon: Icons.grade_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return "กรอก GPA";
                                  }

                                  final gpa = double.tryParse(value.trim());

                                  if (gpa == null || gpa < 0 || gpa > 4) {
                                    return "GPA ต้อง 0.00-4.00";
                                  }

                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // =================================================
                  // ปุ่ม
                  // =================================================
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffeba6d0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 6,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isEdit ? "บันทึกการแก้ไข" : "เพิ่มผู้ใช้",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
