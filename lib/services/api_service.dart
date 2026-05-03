import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';

class ApiService {
  // Use 'http://localhost:3000/api' for Windows/Web testing.
  // Use 'http://10.0.2.2:3000/api' for Android Emulator.
  // Use your computer's IP for physical device testing.
  static const String baseUrl = 'http://10.114.209.35:3000/api';

  Future<AppSettings> getSettings() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/settings'));
      if (response.statusCode == 200) {
        return AppSettings.fromJson(jsonDecode(response.body));
      }
      throw Exception('Server returned ${response.statusCode}');
    } catch (e) {
      print('❌ ApiService Error (getSettings): $e');
      rethrow;
    }
  }

  Future<void> updateSettings(Map<String, dynamic> updates) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updates),
      );
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('❌ ApiService Error (updateSettings): $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getHistory(String range) async {
    final response = await http.get(Uri.parse('$baseUrl/history?range=$range'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<double> getDailyUsage(String fromDate) async {
    final response = await http.get(
      Uri.parse('$baseUrl/daily-usage?fromDate=$fromDate'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['totalKWhConsumed'] ?? 0).toDouble();
    }
    return 0.0;
  }

  Future<List<dynamic>> getNotifications() async {
    final response = await http.get(Uri.parse('$baseUrl/notifications'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<void> clearNotifications() async {
    await http.delete(Uri.parse('$baseUrl/notifications'));
  }

  Future<void> deleteNotification(String id) async {
    await http.delete(Uri.parse('$baseUrl/notifications/$id'));
  }
}
