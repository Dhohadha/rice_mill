import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) return 'http://10.156.12.35:8000';
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return 'http://10.156.12.35:8000';
      }
    } catch (_) {}
    return 'http://localhost:8000';
  }
}
