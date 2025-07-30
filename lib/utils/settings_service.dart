import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  // Default urls
  static const String _defaultBaseUrl = "http://192.168.17.211:5000/telemetry";
  static const String _defaultNotificationUrl = "http://192.168.17.211:5000/notification";

  // Keys for storage
  static const String _baseUrlKey = 'baseUrl';
  static const String _notificationUrlKey = 'notificationUrl';

  // Getters
  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
  }

  Future<String> getNotificationUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_notificationUrlKey) ?? _defaultNotificationUrl;
  }

  // Savers
  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }

  Future<void> setNotificationUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notificationUrlKey, url);
  }
}