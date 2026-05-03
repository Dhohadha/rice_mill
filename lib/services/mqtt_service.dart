import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/meter_data.dart';

class MqttService {
  late MqttServerClient client;
  final String broker = 'broker.emqx.io';
  final String topic = 'EMS1/data';

  final _dataStreamController = StreamController<MeterData>.broadcast();
  Stream<MeterData> get dataStream => _dataStreamController.stream;

  Future<void> connect() async {
    client = MqttServerClient(broker, 'flutter_client_${Random().nextInt(100000)}');
    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.logging(on: false);

    client.onDisconnected = () {
      // Handle disconnection
    };

    try {
      await client.connect();
    } catch (e) {
      client.disconnect();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      client.subscribe(topic, MqttQos.atMostOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        final recMess = c![0].payload as MqttPublishMessage;
        final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        debugPrint('📩 MQTT Received: $pt');

        try {
          final json = jsonDecode(pt);
          if (json['status'] != 'no_data') {
            _dataStreamController.add(MeterData.fromJson(json));
          }
        } catch (e) {
          debugPrint('❌ MQTT Parse Error: $e');
        }
      });
    } else {
      debugPrint('❌ MQTT connection failed');
      client.disconnect();
    }
  }

  void disconnect() {
    client.disconnect();
    _dataStreamController.close();
  }
}
