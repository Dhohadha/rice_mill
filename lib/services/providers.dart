import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../models/meter_data.dart';
import '../services/mqtt_service.dart';
import '../services/notification_service.dart';
import '../services/alarm_service.dart';
import '../services/api_service.dart';


final apiServiceProvider = Provider((ref) => ApiService());
final mqttServiceProvider = Provider((ref) => MqttService());
final notificationServiceProvider = Provider((ref) => NotificationService());
final alarmServiceProvider = Provider((ref) => AlarmService());

// Settings Provider
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings?>(() {
  return SettingsNotifier();
});

class SettingsNotifier extends Notifier<AppSettings?> {
  late ApiService _apiService;

  @override
  AppSettings? build() {
    _apiService = ref.watch(apiServiceProvider);
    loadSettings();
    return null;
  }

  Future<void> loadSettings() async {
    try {
      final settings = await _apiService.getSettings();
      state = settings;
    } catch (e) {
      // Error logging can be handled by a dedicated service in production
    }
  }

  Future<void> updateSettings(Map<String, dynamic> updates) async {
    try {
      await _apiService.updateSettings(updates);
      await loadSettings();
    } catch (e) {
      // Error logging
    }
  }
}

// MQTT Data Provider
final mqttDataProvider = StreamProvider<MeterData>((ref) async* {
  final mqtt = ref.watch(mqttServiceProvider);
  await mqtt.connect();
  yield* mqtt.dataStream;
});

// Selected Date Provider using Notifier (replacement for StateProvider)
final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(() {
  return SelectedDateNotifier();
});

class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now().subtract(const Duration(days: 30));
  
  void setDate(DateTime date) => state = date;
}

// Consumed KWH Provider
final consumedKwhProvider = FutureProvider<double>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final date = ref.watch(selectedDateProvider);
  final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  return await api.getDailyUsage(dateStr);
});

// Graph Toggle Provider using Notifier
final isDayGraphProvider = NotifierProvider<IsDayGraphNotifier, bool>(() {
  return IsDayGraphNotifier();
});

class IsDayGraphNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  
  void toggle(bool value) => state = value;
}

// Graph Data Provider
final graphDataProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final isDay = ref.watch(isDayGraphProvider);
  return await api.getHistory(isDay ? 'day' : 'hour');
});

// Notifications Provider using AsyncNotifier
final notificationsProvider = AsyncNotifierProvider<NotificationsNotifier, List<dynamic>>(() {
  return NotificationsNotifier();
});

class NotificationsNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  FutureOr<List<dynamic>> build() async {
    final api = ref.watch(apiServiceProvider);
    return await api.getNotifications();
  }

  Future<void> deleteNotification(String id) async {
    final api = ref.read(apiServiceProvider);
    
    // 1. Optimistically update local state immediately
    if (state.hasValue) {
      final currentList = state.value!;
      state = AsyncData(currentList.where((n) => (n['_id']?.toString() ?? '') != id).toList());
    }

    try {
      // 2. Perform the server-side deletion
      await api.deleteNotification(id);
    } catch (e) {
      // 3. Rolling back if server deletion fails
      ref.invalidateSelf();
    }
  }

  Future<void> clearNotifications() async {
    final api = ref.read(apiServiceProvider);
    state = const AsyncData([]);
    try {
      await api.clearNotifications();
    } catch (e) {
      ref.invalidateSelf();
    }
  }
}
