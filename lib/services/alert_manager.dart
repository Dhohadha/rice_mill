import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';
import 'alarm_service.dart';
import 'providers.dart';
import '../models/meter_data.dart';
import '../models/app_settings.dart';

class AlertState {
  final bool isAlarmPlaying;
  final bool isAlarmStopped;
  final List<String> activeAlerts;

  AlertState({
    this.isAlarmPlaying = false,
    this.isAlarmStopped = false,
    this.activeAlerts = const [],
  });

  AlertState copyWith({
    bool? isAlarmPlaying,
    bool? isAlarmStopped,
    List<String>? activeAlerts,
  }) {
    return AlertState(
      isAlarmPlaying: isAlarmPlaying ?? this.isAlarmPlaying,
      isAlarmStopped: isAlarmStopped ?? this.isAlarmStopped,
      activeAlerts: activeAlerts ?? this.activeAlerts,
    );
  }
}

class AlertManager extends Notifier<AlertState> {
  final NotificationService _notificationService = NotificationService();
  final AlarmService _alarmService = AlarmService();

  // Track last alert time to prevent notification spam.
  // Cleared when value goes back to normal so re-trigger works correctly.
  final Map<String, DateTime> _lastAlertTime = {};
  final Duration _alertCooldown = const Duration(minutes: 5);

  // Track which alert types are currently breached
  final Set<String> _activeBreaches = {};

  @override
  AlertState build() {
    // Use ref.listen for side effects — never modify state inside build()
    ref.listen(mqttDataProvider, (previous, next) {
      final settings = ref.read(settingsProvider);
      if (next.hasValue && settings != null) {
        _checkThresholds(next.value!, settings);
      }
    });

    ref.listen(settingsProvider, (previous, next) {
      if (next != null) {
        final meterData = ref.read(mqttDataProvider);
        if (meterData.hasValue) {
          _checkThresholds(meterData.value!, next);
        }
      }
    });

    return AlertState();
  }

  void _checkThresholds(MeterData data, AppSettings settings) {
    final List<String> currentAlerts = [];
    bool shouldTriggerAlarm = false;

    // ---- CMD Check ----
    if (data.kVATotal > 0 && data.kVATotal > settings.cmdLimit) {
      currentAlerts.add('CMD Exceeded: ${data.kVATotal.toStringAsFixed(1)} kVA > ${settings.cmdLimit.toStringAsFixed(1)} kVA');
      shouldTriggerAlarm = true;
      _maybeNotify('CMD', '⚡ CMD Limit Exceeded', 'Current demand is ${data.kVATotal.toStringAsFixed(1)} kVA');
      _activeBreaches.add('CMD');
    } else {
      // Value returned to normal — clear cooldown so next breach re-notifies immediately
      if (_activeBreaches.remove('CMD')) {
        _lastAlertTime.remove('CMD');
      }
    }

    // ---- Power Check ----
    if (data.kWTotal > 0 && data.kWTotal > settings.powerLimit) {
      currentAlerts.add('Power Exceeded: ${data.kWTotal.toStringAsFixed(1)} kW > ${settings.powerLimit.toStringAsFixed(1)} kW');
      shouldTriggerAlarm = true;
      _maybeNotify('POWER', '⚡ Power Limit Exceeded', 'Current power is ${data.kWTotal.toStringAsFixed(1)} kW');
      _activeBreaches.add('POWER');
    } else {
      if (_activeBreaches.remove('POWER')) {
        _lastAlertTime.remove('POWER');
      }
    }

    // ---- PF Check ----
    if (data.pfAvg > 0 && data.pfAvg < settings.pfLimit) {
      currentAlerts.add('Low Power Factor: ${data.pfAvg.toStringAsFixed(3)} < ${settings.pfLimit.toStringAsFixed(2)}');
      shouldTriggerAlarm = true;
      _maybeNotify('PF', '⚠️ Low Power Factor', 'Current PF is ${data.pfAvg.toStringAsFixed(3)}');
      _activeBreaches.add('PF');
    } else {
      if (_activeBreaches.remove('PF')) {
        _lastAlertTime.remove('PF');
      }
    }

    // Trigger or auto-stop alarm
    if (shouldTriggerAlarm && !state.isAlarmPlaying) {
      _alarmService.playAlarm();
      state = state.copyWith(isAlarmPlaying: true, isAlarmStopped: false, activeAlerts: currentAlerts);
    } else {
      // Update displayed alerts even while alarm playing
      if (currentAlerts.join(',') != state.activeAlerts.join(',')) {
        state = state.copyWith(activeAlerts: currentAlerts);
      }
      // Auto-stop alarm when all values are back to normal
      if (currentAlerts.isEmpty && state.isAlarmPlaying) {
        stopAlarm();
      }
    }
  }

  void _maybeNotify(String type, String title, String body) {
    final now = DateTime.now();
    final lastTime = _lastAlertTime[type];

    if (lastTime == null || now.difference(lastTime) > _alertCooldown) {
      _notificationService.showThresholdAlert(
        id: type.hashCode.abs(),
        title: title,
        body: body,
        payload: 'history',
      );
      _lastAlertTime[type] = now;
    }
  }

  void stopAlarm() {
    _alarmService.stopAlarm();
    state = state.copyWith(isAlarmPlaying: false, isAlarmStopped: true);
  }
}

final alertManagerProvider = NotifierProvider<AlertManager, AlertState>(() {
  return AlertManager();
});
