import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rice_mill/services/alert_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/fcm_service.dart';
import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
import 'services/notification_service.dart';
import 'services/providers.dart';

Future<void> _requestPermissions() async {
  if (Platform.isAndroid) {
    // Request notification permission (Android 13+)
    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      await Permission.notification.request();
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  
  await _requestPermissions();

  final notificationService = NotificationService();
  await notificationService.init();

  final fcmService = FCMService();
  await fcmService.init();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupNotificationListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupNotificationListeners() {
    final notificationService = NotificationService();

    notificationService.onNotificationTap = (payload) {
      if (payload == 'history') {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      }
    };

    notificationService.onStopAlarmAction = () {
      ref.read(alertManagerProvider.notifier).stopAlarm();
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(mqttServiceProvider).disconnect();
      ref.read(alertManagerProvider.notifier).stopAlarm();
    } else if (state == AppLifecycleState.resumed) {
      // Check if the Stop button was tapped while in background
      ref.read(alertManagerProvider.notifier).syncStopState();
      // Reconnect MQTT
      ref.invalidate(mqttDataProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rice Mill Monitoring',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          titleMedium: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
