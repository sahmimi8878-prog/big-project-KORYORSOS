import 'package:flutter/material.dart';
 
/// สีต่าง ๆ ที่ใช้ในแอป (ดึงโทนสีมาจากภาพตัวอย่างหน้าแรก: ชมพู-ม่วงพาสเทล)
class AppColors {
  // ไล่สีของ header / ปุ่มหลัก
  static const Color gradientStart = Color(0xFFF7D9EC); // ชมพูอ่อน
  static const Color gradientEnd = Color(0xFFDCD3F6); // ม่วงลาเวนเดอร์อ่อน
 
  // สีการ์ดแต่ละประเภท (ตามภาพ: ข้อมูลผู้ใช้ / เอกสาร / การจอง)
  static const Color cardPurple = Color(0xFFC7C0EC); // การ์ด "ข้อมูลผู้ใช้"
  static const Color cardCream = Color(0xFFFBEAE2); // การ์ด "เอกสาร"
  static const Color cardPink = Color(0xFFEC93BE); // การ์ด "การจอง"
 
  static const Color background = Color(0xFFF6F2FB);
  static const Color textDark = Color(0xFF5A4A6B);
  static const Color textOnPink = Color(0xFF6A2E4E);
  static const Color iconPurple = Color(0xFF6C63A6);
  static const Color chipFull = Color(0xFFE0DCEA);
  static const Color chipFullText = Color(0xFF9C93AE);
}
 