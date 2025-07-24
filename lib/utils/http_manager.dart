import 'dart:convert';
import 'package:http/http.dart' as http;

class SendResult {
  final bool success;
  final String message;
  SendResult({required this.success, required this.message});
}

class HttpManager {
  // sesuaikan url
  // final String _baseUrl = "http://localhost:5216/api/telemetry"; // Untuk simulator 
  final String _baseUrl = "http://192.168.17.211:5000/telemetry"; // untuk di hp

  // Ganti URL ini dengan URL endpoint notifikasi dashboard Anda yang sebenarnya!
  final String _notificationUrl = "http://192.168.17.211:5000/notification"; // Untuk notifikasi dashboard

  Future<SendResult> sendData(Map<String, dynamic> telemetryData) async {
    try {
      if (telemetryData.containsKey('tag_button') && telemetryData['tag_button'] is bool) {
        telemetryData['tag_button'] = telemetryData['tag_button'] ? 1 : 0;
      }

      String jsonData = jsonEncode(telemetryData);
      print("===================================");
      print("REAL: Mengirim JSON ke Server...");
      print("REAL: URL: $_baseUrl");
      print("REAL: Payload: $jsonData");
      print("===================================");

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(telemetryData),
      ).timeout(const Duration(seconds: 10)); // Timeout 

      if (response.statusCode == 200) {
        print("REAL: Data berhasil dikirim. Server response: ${response.body}");
        return SendResult(success: true, message: "Data berhasil dikirim.");
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

  // Fungsi untuk mengirim notifikasi ke dashboard
  Future<void> sendNotificationToDashboard({
    required String deviceId,
    required int totalRecordsSent,
    required String status,
    String? errorMessage,
  }) async {
    final payload = {
      'device_id': deviceId,
      'total_records_sent': totalRecordsSent,
      'status': status, // e.g., "success", "failed", "resend"
      'error_message': errorMessage,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      print("REAL: Mengirim notifikasi ke dashboard...");
      print("REAL: URL Notifikasi: $_notificationUrl");
      print("REAL: Payload Notifikasi: ${jsonEncode(payload)}");

      final response = await http.post(
        Uri.parse(_notificationUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print("REAL: Notifikasi dashboard berhasil dikirim.");
      } else {
        print("REAL: Gagal mengirim notifikasi dashboard. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      print("REAL: Error jaringan saat mengirim notifikasi dashboard: $e");
    }
  }
}
