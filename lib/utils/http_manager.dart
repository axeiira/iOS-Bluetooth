import 'dart:convert';
import 'package:http/http.dart' as http;

class SendResult {
  final bool success;
  final String message;
  SendResult({required this.success, required this.message});
}

class HttpManager {
  // final String _baseUrl = "http://localhost:5216/api/telemetry/upload"; // buat di simulator
  final String _baseUrl = "http://192.168.17.211:5000/telemetry"; // buat di hp

  Future<SendResult> sendData(Map<String, dynamic> telemetryData) async {
    try {
      // debug
      String jsonData = jsonEncode(telemetryData);
      print("===================================");
      print("Mengirim JSON ke Server...");
      print("URL: $_baseUrl");
      print("Payload: $jsonData");
      print("===================================");

      // kirim data ke server
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(telemetryData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return SendResult(success: true, message: "Data berhasil dikirim.");
      } else {
        return SendResult(
          success: false,
          message: "Server merespon dengan error. Status: ${response.statusCode}\nBody: ${response.body}",
        );
      }
    } catch (e) {
      return SendResult(
        success: false,
        message: "Error Jaringan: ${e.toString()}",
      );
    }
  }
}