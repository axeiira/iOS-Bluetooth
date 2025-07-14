import 'dart:convert';
import 'package:http/http.dart' as http;

class HttpManager {
  // final String _baseUrl = "http://192.168.17.209:5216/api/telemetry/upload";  // buat hp asli
  final String _baseUrl = "http://localhost:5216/api/telemetry/upload"; // buat simulator
  
  Future<bool> sendData(Map<String, dynamic> telemetryData) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(telemetryData),
      );

      if (response.statusCode == 200) {
        print("Data berhasil dikirim: ${response.body}");
        return true;
      } else {
        print("Gagal mengirim data. Status: ${response.statusCode}, Body: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error mengirim data (HTTP): $e");
      return false;
    }
  }
}