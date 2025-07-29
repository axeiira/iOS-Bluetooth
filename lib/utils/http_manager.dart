import 'dart:convert';
import 'package:http/http.dart' as http;

class SendResult {
  final bool success;
  final String message;
  final int count;
  SendResult({required this.success, required this.message, this.count=0});
}

class HttpManager {
  final String _baseUrl = "http://192.168.17.210:6432/api/telemetry";
  final String _notificationUrl = "http://192.168.17.211:5000/notification";

  Future<SendResult> sendData(Map<String, dynamic> telemetryData) async {
    try {
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
        body: jsonData,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
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

  Future<void> sendNotificationToDashboard({
    required String deviceId,
    required int totalRecordsSent,
    required String status,
    String? errorMessage,
  }) async {
    // TODO
  }

  Future<SendResult> sendBulkData(List<Map<String, dynamic>> telemetryList) async {
    try {
      String jsonData = jsonEncode(telemetryList);
      print("===================================");
      print("REAL: Mengirim BATCH DATA ke Server...");
      print("REAL: URL: $_baseUrl");
      print("REAL: Total Records: ${telemetryList.length}");
      print("===================================");

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonData,
      ).timeout(const Duration(seconds: 60)); // Timeout lebih lama untuk data besar

      if (response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        final count = responseBody['count'] ?? 0;
        print("REAL: Batch data berhasil dikirim. Server response: ${response.body}");
        return SendResult(success: true, message: "Batch data berhasil dikirim.", count: count);
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
}