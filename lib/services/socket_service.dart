import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/meter_data.dart';
import 'api_service.dart';

class SocketService {
  IO.Socket? socket;
  final _dataStreamController = StreamController<MeterData>.broadcast();
  Stream<MeterData> get dataStream => _dataStreamController.stream;

  final Set<String> _joinedRooms = {};

  void connect(String deviceId) {
    if (socket == null) {
      debugPrint('🔄 Initializing WebSocket connection...');
      socket = IO.io(ApiService.baseUrl, IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build());

      socket!.onConnect((_) {
        debugPrint('✅ WebSocket Connected to ${ApiService.baseUrl}');
        // Re-join all active rooms on reconnect
        for (var room in _joinedRooms) {
          socket!.emit('joinDeviceRoom', room);
        }
      });

      socket!.onConnectError((err) => debugPrint('❌ WebSocket Connect Error: $err'));
      socket!.on('error', (err) => debugPrint('❌ WebSocket Socket Error: $err'));
      socket!.on('reconnect', (_) => debugPrint('🔄 WebSocket Reconnecting...'));

      socket!.on('meterData', (data) {
        debugPrint('📩 WebSocket Received meterData for ${data['deviceId']}');
        try {
          if (data['status'] != 'no_data') {
            _dataStreamController.add(MeterData.fromJson(data));
          }
        } catch (e) {
          debugPrint('❌ WebSocket Parse Error: $e');
        }
      });

      socket!.onDisconnect((_) {
        debugPrint('⚠️ WebSocket Disconnected.');
      });
    }

    if (!_joinedRooms.contains(deviceId)) {
      _joinedRooms.add(deviceId);
      if (socket!.connected) {
        debugPrint('🏠 Joining room: $deviceId');
        socket!.emit('joinDeviceRoom', deviceId);
      }
    }
  }

  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    _joinedRooms.clear();
  }
}
