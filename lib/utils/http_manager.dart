import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> getDailySummary(
    String date, {
    String? deviceId,
    String? employeeName,
  }) async {
    final String baseTelemetryUrl = await _settingsService.getBaseUrl();
    final Uri baseUri = Uri.parse(baseTelemetryUrl);
    
    final queryParameters = <String, String>{'date': date};
    if (deviceId != null && deviceId.isNotEmpty) {
      queryParameters['deviceId'] = deviceId;
    }
    if (employeeName != null && employeeName.isNotEmpty) {
      queryParameters['employeeName'] = employeeName;
    }

    final url = baseUri.replace(
      path: '/api/telemetry/daily-summary',
      queryParameters: queryParameters,
    ).toString();
    
    // debug logging
    if (kDebugMode) {
      print("================ HTTP MANAGER DEBUG ================");
      print("Memanggil URL: $url");
      print("====================================================");
    }
    
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(url), headers: headers);

      // debug logging
      if (kDebugMode) {
        print("================ HTTP MANAGER DEBUG ================");
        print("Status Kode dari Server: ${response.statusCode}");
        print("Body Respons dari Server (Raw):");
        print(response.body);
        print("====================================================");
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['summary'] is List) {
          return List<Map<String, dynamic>>.from(data['summary']);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error saat memanggil getDailySummary: $e");
      }
    }
    return [];
  }


  Future<SendResult> sendBulkData(List<Map<String, dynamic>> telemetryList) async {
    final String baseUrl = await _settingsService.getBaseUrl();
    try {
      String jsonData = jsonEncode(telemetryList);
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonData,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 201 || response.statusCode == 202) {
        final responseBody = jsonDecode(response.body);
        final count = responseBody['count'] ?? telemetryList.length;
        return SendResult(success: true, message: "Batch data accepted by server.", count: count);
      } else {
        return SendResult(
          success: false,
          message: "Server error. Status: ${response.statusCode}\nBody: ${response.body}",
        );
      }
    } catch (e) {
      return SendResult(success: false, message: "Network Error: ${e.toString()}");
    }
  }

  Future<SendResult> sendPairings(List<Map<String, dynamic>> pairingsList) async {
    final String baseTelemetryUrl = await _settingsService.getBaseUrl();
    final Uri baseUri = Uri.parse(baseTelemetryUrl);
    final String assignUrl = baseUri.replace(path: '/api/device-assignments/assign').toString();
    try {
      String jsonData = jsonEncode(pairingsList);
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(assignUrl),
        headers: headers,
        body: jsonData,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201 || response.statusCode == 202) {
        return SendResult(success: true, message: "Pairings sent successfully.");
      } else {
        return SendResult(success: false, message: "Server error: ${response.statusCode}");
      }
    } catch (e) {
      return SendResult(success: false, message: "Network Error: ${e.toString()}");
    }
  }

  Future<List<String>> getActiveDates() async {
    final String baseTelemetryUrl = await _settingsService.getBaseUrl();
    final Uri baseUri = Uri.parse(baseTelemetryUrl);
    final url = baseUri.replace(path: '/api/telemetry/active-dates').toString();
    
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['dates'] is List) {
          return List<String>.from(data['dates']);
        }
      }
    } catch (e) {
      print("Error fetching active dates: $e");
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getRouteDetails(int deviceId, String date) async {
    final String baseTelemetryUrl = await _settingsService.getBaseUrl();
    final Uri baseUri = Uri.parse(baseTelemetryUrl);
    final url = baseUri.replace(
      path: '/api/telemetry/$deviceId/track',
      queryParameters: {'date': date},
    ).toString();

    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['track'] is List) {
          return List<Map<String, dynamic>>.from(data['data']['track']);
        }
      }
    } catch (e) {
      print("Error fetching route details: $e");
    }
    return [];
  }
}
