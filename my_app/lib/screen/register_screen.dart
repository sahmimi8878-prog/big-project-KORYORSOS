import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '/login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // key สำหรับตรวจสอบความถูกต้องของฟอร์ม (validate)
  final _formKey = GlobalKey<FormState>();

  // ---------- controller สำหรับรับข้อมูลจากผู้ใช้ ----------
  // ข้อมูลตาราง Users
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ข้อมูลตาราง Student_Profiles
  final _studentCodeController = TextEditingController();
  final _citizenIdController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _facultyController = TextEditingController();
  final _majorController = TextEditingController();
  final _gpaController = TextEditingController();

  // เก็บวันเกิดที่ผู้ใช้เลือกจากปฏิทิน
  DateTime? _birthDate;

  // ชั้นปีของนักศึกษา (1-4)
  int? _selectedYear;

  // คำนำหน้า
  String? _selectedPrefix;

  // แสดง/ซ่อนรหัสผ่าน
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // สถานะตอนกำลังส่งข้อมูลไป server
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  // ---------- เลือกวันเกิดผ่านปฏิทิน ----------
  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
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
    // แปลง DateTime เป็น String รูปแบบ yyyy-MM-dd เพื่อส่งไป server
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }

  // ---------- ฟังก์ชันสำหรับการลงทะเบียน (ตามแพทเทิร์น _doCreateActivity ใน workshop) ----------
  Future<void> _doRegister() async {
    // ตรวจสอบความถูกต้องของฟอร์มก่อน
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

    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage("รหัสผ่านไม่ตรงกันนะ ลองเช็คอีกทีน้า");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // สร้างข้อมูลที่จะส่งไป server แบบ post (ต้องเป็น JSON)
    final Map<String, dynamic> data = {
      "email": _emailController.text.trim(),
      "password": _passwordController.text,
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
    };

    try {
      // ยังไม่มี access_token ตอนลงทะเบียน จึงเรียก http.post ตรง ๆ
      // (คนละแบบกับ AppApi.get/post ที่ต้องแนบ token)
      final response = await http.post(
        Uri.parse(AppConfig.register),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      setState(() {
        _isLoading = false;
      });

      // server ของเราตอบ HTTP 200 เสมอ แล้วบอกผลจริงผ่าน field "isError" ใน body
      // (เหมือน endpoint อื่น ๆ เช่น /api/authen/access_request)
      final json = jsonDecode(response.body);
      final bool isError = json["isError"] ?? true;

      if (!isError) {
        _showMessage("ลงทะเบียนสำเร็จ ✨ เข้าสู่ระบบได้เลยน้า");

        // หน่วงเวลานิดนึงให้เห็นข้อความ แล้วค่อยกลับไปหน้า login
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        _showMessage(json["errorMessage"] ?? "ลงทะเบียนไม่สำเร็จ ลองใหม่อีกครั้งน้า");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage("เชื่อมต่อ server ไม่ได้ ลองเช็คอินเทอร์เน็ตดูน้า");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xff8B6FA3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // ธีมพื้นหลังไล่สีพาสเทลชมพู-ม่วง แบบเดียวกับหน้า Home
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// HEADER
                  const SizedBox(height: 10),
                  const Text(
                    "ลงทะเบียน 🌸",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff8B6FA3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "กรอกข้อมูลของน้อง ๆ ให้ครบก่อนเข้าใช้งานน้า",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 25),

                  /// การ์ดฟอร์มลงทะเบียน
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
                        const SizedBox(height: 14),

                        _buildTextField(
                          controller: _passwordController,
                          label: "รหัสผ่าน",
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
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
                        const SizedBox(height: 14),

                        _buildTextField(
                          controller: _confirmPasswordController,
                          label: "ยืนยันรหัสผ่าน",
                          icon: Icons.lock_outline,
                          obscureText: _obscureConfirm,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirm = !_obscureConfirm;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "กรุณายืนยันรหัสผ่าน";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 22),
                        _sectionTitle("ข้อมูลนักศึกษา"),
                        const SizedBox(height: 12),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ---------- คำนำหน้า ----------
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
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xffeba6d0),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                items: const ["นาย", "นาง", "นางสาว"]
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(p, style: const TextStyle(fontSize: 13)),
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

                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _lastNameController,
                                label: "นามสกุล",
                                icon: Icons.badge_outlined,
                                validator: _requiredValidator,
                              ),
                            ),
                          ],
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

                        // ---------- ตัวเลือกวันเกิด ----------
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
                              border: Border.all(color: const Color(0xffe0d4f7)),
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
                          children: [
                            // ---------- เลือกชั้นปี ----------
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedYear,
                                decoration: InputDecoration(
                                  labelText: "ชั้นปี",
                                  prefixIcon: const Icon(
                                    Icons.stairs_outlined,
                                    color: Color(0xff8B6FA3),
                                    size: 20,
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
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xffeba6d0),
                                      width: 1.5,
                                    ),
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

                            // ---------- กรอก GPA ----------
                            Expanded(
                              child: _buildTextField(
                                controller: _gpaController,
                                label: "GPA",
                                icon: Icons.grade_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
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

                  /// ปุ่มลงทะเบียน
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _doRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffeba6d0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 6,
                        shadowColor: const Color.fromRGBO(120, 90, 160, 0.4),
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
                          : const Text(
                              "ลงทะเบียน",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// ลิงก์กลับไปหน้า login
                  Center(
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
                      child: const Text.rich(
                        TextSpan(
                          text: "มีบัญชีอยู่แล้ว? ",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                          children: [
                            TextSpan(
                              text: "เข้าสู่ระบบ",
                              style: TextStyle(
                                color: Color(0xff8B6FA3),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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

  // ---------- ฟอร์มอินพุตแบบมาตรฐาน คุมธีมให้อยู่ในโทนแอ๊บแบ๊ว ----------
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
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
        suffixIcon: suffixIcon,
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
}