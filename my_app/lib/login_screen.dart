import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:my_app/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/utils/data_utils.dart';

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

  Future<(bool, String, String)> _authenRequest() async {
    String username = _emailController.text;

    DateTime now = DateTime.now();
    String formattedDate = DateUtil.getFormattedDate(now);

    String authenRequest = sha256
        .convert(utf8.encode("$username&$formattedDate"))
        .toString();

    final response = await http.post(
      Uri.parse(AppConfig.authenRequest),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"authen_request": authenRequest}),
    );

    final json = jsonDecode(response.body);

    return (
      json["isError"] as bool,
      json["data"] as String,
      json["errorMessage"] as String,
    );
  }

  Future<({bool isError, String data, String errorMessage})> _accessRequest(
    String authenToken,
  ) async {
    String username = _emailController.text;
    String password = _passwordController.text;

    String passwordHash = sha256.convert(utf8.encode(password)).toString();

    String authenSignature = sha256
        .convert(utf8.encode("$username&$passwordHash&$authenToken"))
        .toString();

    final response = await http.post(
      Uri.parse(AppConfig.accessRequest),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "authen_signature": authenSignature,
        "authen_token": authenToken,
      }),
    );

    final json = jsonDecode(response.body);

    if (!json["isError"]) {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString("access_token", json["data"]["access_token"]);

      await prefs.setString("username", username);
    }

    return (
      isError: (json["isError"] ?? true) as bool,
      data: json["data"]["access_token"] as String,
      errorMessage: json["errorMessage"] as String,
    );
  }

  void _doLogin(BuildContext context) async {
    var (isError, authenToken, errorMessage) = await _authenRequest();

    if (isError) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(content: Text(errorMessage)),
      );
      return;
    }

    var result = await _accessRequest(authenToken);

    if (!result.isError) {
      print(result.data);
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(content: Text(result.errorMessage)),
      );
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF5FC), Color(0xFFF8EEFF), Color(0xFFEEE8FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCard(),

                  const SizedBox(height: 20),

                  const Text(
                    "KORYORSOS For PSU Students",
                    style: TextStyle(
                      color: Color(0xFFFF78C6),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 26),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: .18),
            blurRadius: 35,
            offset: Offset(0, 15),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20), // ความโค้งของมุม
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 25,
                        color: Colors.pink.withValues(alpha: .25),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/images/logo3.jpg',
                      width: 180,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Center(
              child: Column(
                children: const [
                  Text(
                    "KORYORSOS",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF78C6),
                      letterSpacing: 1.2,
                    ),
                  ),

                  Text(
                    "Welcome to KORYORSOS",
                    style: TextStyle(fontSize: 14, color: Color(0xFF9A6BFF)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ----- Username -----
            _fieldLabel("Email"),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(hint: "กรอกอีเมล").copyWith(
                prefixIcon: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFFFF78C6),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ----- Password -----
            _fieldLabel("รหัสผ่าน"),
            const SizedBox(height: 6),

            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: _inputDecoration(hint: "กรอกรหัสผ่าน").copyWith(
                prefixIcon: const Icon(
                  Icons.lock_rounded,
                  color: Color(0xFFFF78C6),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
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
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() {
                      _rememberMe = !_rememberMe;
                    });
                  },
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _rememberMe
                              ? const Color(0xFFFF8FD8)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFF8FD8),
                            width: 1.8,
                          ),
                        ),
                        child: _rememberMe
                            ? const Icon(
                                Icons.favorite,
                                color: Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "จดจำการเข้าสู่ระบบ",
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B6283),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                TextButton(
                  onPressed: () {},

                  style: TextButton.styleFrom(padding: EdgeInsets.zero),

                  child: const Text(
                    "ลืมรหัสผ่าน?",
                    style: TextStyle(
                      color: Color(0xFFFF78C6),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ----- ปุ่ม SIGN IN -----
            SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8FD8), Color(0xFFC98CFF)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withValues(alpha: 0.35),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("กำลังเข้าสู่ระบบ... 💖")),
                      );
                      _doLogin(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        "LOGIN",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ----- Not registered? Sign up -----
            Center(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8D85A5),
                  ),
                  children: [
                    const TextSpan(text: "ยังไม่มีบัญชีผู้ใช้งาน? "),
                    TextSpan(
                      text: "ลงทะเบียน 💖",
                      style: const TextStyle(
                        color: Color(0xFFFF78C6),
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
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B6283),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB4A7C8), fontSize: 14),

      filled: true,
      fillColor: Colors.white,

      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.pinkAccent.shade100, width: 1.2),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFFF78C6), width: 2),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }
}
