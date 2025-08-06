import 'dart:convert';
import 'package:http/http.dart' as http;
import 'settings_service.dart';
import 'auth_service.dart';

class SendResult {
  final bool success;
  final String message;
  final int count;
  SendResult({required this.success, required this.message, this.count=0});
}

class HttpManager {
  final SettingsService _settingsService = SettingsService();
  final AuthService _authService = AuthService(); // Tambahkan instance AuthService

  // Fungsi untuk mendapatkan header dengan token autentikasi
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<SendResult> sendBulkData(List<Map<String, dynamic>> telemetryList) async {
    final String baseUrl = await _settingsService.getBaseUrl();
    
    try {
      String jsonData = jsonEncode(telemetryList);
      final headers = await _getHeaders(); // Dapatkan header dengan token

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers, // Gunakan header yang sudah ada tokennya
        body: jsonData,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 201 || response.statusCode == 202) {
        final responseBody = jsonDecode(response.body);
        // Coba dapatkan 'count' dari respons, jika tidak ada, hitung dari data yang dikirim
        final count = responseBody['count'] ?? telemetryList.length;
        print("REAL: Batch data berhasil diterima oleh server. Server response: ${response.body}");
        return SendResult(success: true, message: "Batch data berhasil diterima oleh server.", count: count);
      } else {
        print("REAL: Server merespon dengan error. Status: ${response.statusCode}\nBody: ${response.body}");
        return SendResult(
          success: false,
          message: "Server merespon dengan error. Status: ${response.statusCode}\nBody: ${response.body}",
        );
      }
    } catch (e) {
      print("REAL: Error Jaringan: ${e.toString()}");
      return SendResult(
        success: false,
        message: "Error Jaringan: ${e.toString()}",
      );
    }
  }

  Future<SendResult> sendPairings(List<Map<String, dynamic>> pairingsList) async {
    final String baseTelemetryUrl = await _settingsService.getBaseUrl();
    final Uri baseUri = Uri.parse(baseTelemetryUrl);
    final String assignUrl = baseUri.replace(path: '/api/device-assignments/assign').toString();
    
    try {
      String jsonData = jsonEncode(pairingsList);
      final headers = await _getHeaders(); // Dapatkan header dengan token

      final response = await http.post(
        Uri.parse(assignUrl),
        headers: headers, // Gunakan header yang sudah ada tokennya
        body: jsonData,
      ).timeout(const Duration(seconds: 30));

      // Anggap sukses jika status code adalah 201 (Created) ATAU 202 (Accepted)
      if (response.statusCode == 201 || response.statusCode == 202) {
        print("REAL: Batch pairing berhasil diterima oleh server. Server response: ${response.body}");
        return SendResult(success: true, message: "Pairings sent successfully.");
      } else {
        print("REAL: Server merespon dengan error. Status: ${response.statusCode}\nBody: ${response.body}");
        return SendResult(
          success: false,
          message: "Server error: ${response.statusCode}",
        );
      }
    } catch (e) {
      print("REAL: Error Jaringan: ${e.toString()}");
      return SendResult(
        success: false,
        message: "Network Error: ${e.toString()}",
      );
    }
  }
}
