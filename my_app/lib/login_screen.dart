import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:my_app/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
 
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
 
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
 
class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
 
  bool _rememberMe = false;
  bool _obscurePassword = true;
  late final TapGestureRecognizer _signUpRecognizer;
 
  static const Color primaryPurple = Color(0xFF8B7FD8);
  static const Color lightPurple = Color(0xFFB9AEEB);
  static const Color bgLavender = Color(0xFFC9BFEE);
  static const Color pinkBlob = Color(0xFFF3A6C6);
 //แก้ไข
  @override
  void initState() {
    super.initState();
    _signUpRecognizer = TapGestureRecognizer()
      ..onTap = () {
        // TODO: ไปยังหน้า Sign up
      };
  }
 
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _signUpRecognizer.dispose();
    super.dispose();
  }

  Future<void> login() async {
  final response = await http.post(
    Uri.parse(AppConfig.authenRequest),
    headers: {
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "authen_request":
          "${_emailController.text}:${_passwordController.text}",
    }),
  );

  print(response.body);
}
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgLavender, Color(0xFFDCD3F5)],
          ),
        ),
        child: Stack(
          children: [
            // ----- ลูกบอลสีชมพูตกแต่งพื้นหลัง (blurred blobs) -----
            _buildBlob(top: -60, left: -50, size: 160, opacity: 0.55),
            _buildBlob(top: 40, right: -70, size: 130, opacity: 0.45),
            _buildBlob(bottom: -70, left: -40, size: 180, opacity: 0.5),
            _buildBlob(bottom: 60, right: -60, size: 140, opacity: 0.45),
 
            // ----- เนื้อหาหลัก -----
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCard(),
                      const SizedBox(height: 24),
                      _buildSocialRow(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _buildBlob({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required double opacity,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              pinkBlob.withOpacity(opacity),
              pinkBlob.withOpacity(0.0),
            ],
          ),
        ),
      ),
    );
  }
 
  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Log in",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2A45),
              ),
            ),
            const SizedBox(height: 24),
 
            // ----- Email -----
            _fieldLabel("Email"),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(hint: "you@example.com"),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "กรุณากรอกอีเมล";
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
 
            // ----- Password -----
            _fieldLabel("Password"),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: _inputDecoration(hint: "••••••••").copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "กรุณากรอกรหัสผ่าน";
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
 
            // ----- Remember me / Forgot password -----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: primaryPurple,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (v) => setState(() => _rememberMe = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "Remember me",
                      style: TextStyle(fontSize: 12.5, color: Colors.black54),
                    ),
                  ],
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {},
                  child: const Text(
                    "Forgot password?",
                    style: TextStyle(fontSize: 12.5, color: primaryPurple),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
 
            // ----- ปุ่ม SIGN IN -----
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('กำลังเข้าสู่ระบบ...')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "SIGN IN",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
 
            // ----- Not registered? Sign up -----
            Center(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                  children: [
                    const TextSpan(text: "Not registered yet? "),
                    TextSpan(
                      text: "Sign up",
                      style: const TextStyle(
                        color: primaryPurple,
                        fontWeight: FontWeight.bold,
                      ),
                      recognizer: _signUpRecognizer,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        color: Colors.black54,
        fontWeight: FontWeight.w500,
      ),
    );
  }
 
  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
      filled: true,
      fillColor: lightPurple.withOpacity(0.08),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryPurple, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
    );
  }
 
  Widget _buildSocialRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _socialButton(
          icon: Icons.facebook,
          color: const Color(0xFF3B5998),
          onTap: () {},
        ),
        const SizedBox(width: 16),
        _socialButton(
          icon: null,
          letter: "G",
          color: const Color(0xFFDB4437),
          onTap: () {},
        ),
      ],
    );
  }
 
  Widget _socialButton({
    IconData? icon,
    String? letter,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, color: color, size: 22)
            : Text(
                letter ?? "",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
      ),
    );
  }
}
