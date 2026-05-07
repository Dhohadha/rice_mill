import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'notification_service.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
  
  // Initialize NotificationService in background isolate
  final notificationService = NotificationService();
  await notificationService.init();

  String title = message.data['title'] ?? '⚠️ Rice Mill Alert';
  String body = message.data['body'] ?? 'Limit exceeded';

  await notificationService.showThresholdAlert(
    id: 999, // New unified ID
    title: title,
    body: body,
    payload: 'alarm',
  );
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final NotificationService _notificationService = NotificationService();

  Future<void> init() async {
    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions (especially for iOS and Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }

    // Foreground listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      // Extract title and body from data payload since we changed server to send data
      String title = message.data['title'] ?? '⚠️ Rice Mill Alert';
      String body = message.data['body'] ?? 'Limit exceeded';

      _notificationService.showThresholdAlert(
        id: message.hashCode,
        title: title,
        body: body,
        payload: 'alarm',
      );
    });

    // App opened from background/terminated via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from notification!');
      // Navigate to notifications screen or handle payload
    });

    // Get and register token
    String? token = await _fcm.getToken();
    if (token != null) {
      debugPrint("FCM Token: $token");
      await _registerTokenWithBackend(token);
    }

    // Token refresh listener
    _fcm.onTokenRefresh.listen((newToken) {
      _registerTokenWithBackend(newToken);
    });
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      // Using ApiService.baseUrl to ensure consistency with other API calls
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );

      if (response.statusCode == 200) {
        debugPrint('Token registered successfully');
      } else {
        debugPrint('Failed to register token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error registering token: $e');
    }
  }
}
