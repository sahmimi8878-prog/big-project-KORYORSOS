class AppConfig {
  // Flutter Web
  static const String apiBaseUrl = "http://localhost:3000/api";

  // Endpoint
  static const String authenRequest = "$apiBaseUrl/authen/authen_request";
  static const String accessRequest = "$apiBaseUrl/authen/access_request";
  static const String profile = "$apiBaseUrl/profile";
  static const String register = "$apiBaseUrl/register";   // <-- เพิ่มบรรทัดนี้
}