import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';

class ApiService {
  // Using 10.0.2.2 for Android Emulator, localhost for others
  static String get baseUrl {
    if (kIsWeb) return 'http://10.13.108.35:8000';
    try {
      // Use the real IP for mobile debugging
      if (Platform.isAndroid || Platform.isIOS)
        return 'http://10.13.108.35:8000';
    } catch (_) {}
    return 'http://localhost:8000';
  }

  static const String _deviceId = 'RICE_MILL_001';

  Future<AppSettings> getSettings() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/settings'));
      if (response.statusCode == 200) {
        return AppSettings.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching settings: $e');
    }
    return AppSettings(
      cmdLimit: 150,
      cmdMaxGauge: 250,
      powerLimit: 150,
      powerMaxGauge: 250,
      pfLimit: 0.90,
    );
  }

  Future<void> updateSettings(Map<String, dynamic> updates) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updates),
      );
    } catch (e) {
      debugPrint('Error updating settings: $e');
    }
  }

  Future<double> getDailyUsage(String dateStr) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/daily-usage?fromDate=$dateStr'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['totalKWhConsumed'] ?? 0).toDouble();
      }
    } catch (e) {
      debugPrint('Error fetching daily usage: $e');
    }
    return 0.0;
  }

  Future<List<dynamic>> getHistory(String type) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/history?range=$type'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        debugPrint('Failed to load history: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
    }
    return [];
  }

  Future<List<dynamic>> getNotifications() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/notifications'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
    return [];
  }

  Future<void> deleteNotification(String id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/api/notifications/$id'));
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> clearNotifications() async {
    try {
      await http.delete(Uri.parse('$baseUrl/api/notifications'));
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }
}
