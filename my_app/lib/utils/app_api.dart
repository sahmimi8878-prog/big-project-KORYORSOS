import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/config/app_config.dart';

/// ตัวช่วยเรียก API พร้อมแนบ access_token (ที่ login เก็บไว้ใน SharedPreferences)
/// path เริ่มต้นหลัง /api เช่น AppAPI.get("/bookings/list")
class AppAPI {
  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token") ?? "";

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static Future<http.Response> get(String path) async {
    return http.get(
      Uri.parse("${AppConfig.apiBaseUrl}$path"),
      headers: await _headers(),
    );
  }

  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    return http.post(
      Uri.parse("${AppConfig.apiBaseUrl}$path"),
      headers: await _headers(),
      body: jsonEncode(body),
    );
  }
}
