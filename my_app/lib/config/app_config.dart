class AppConfig {
  // Flutter Web
  // host ของ server ล้วนๆ (ใช้ต่อ path รูป เช่น /uploads/xxx.jpg)
  static const String serverUrl = "http://127.0.0.1:3000";

  // base ของ API
  static const String apiBaseUrl = "$serverUrl/api";

  // Endpoint
  static const String authenRequest = "$apiBaseUrl/authen/authen_request";
  static const String accessRequest = "$apiBaseUrl/authen/access_request";
  static const String profile = "$apiBaseUrl/profile";
  static const String register = "$apiBaseUrl/register";

  // Documents
  static const String documents = "$apiBaseUrl/documents";
  static const String officerDocuments = "$apiBaseUrl/officer/document";
}