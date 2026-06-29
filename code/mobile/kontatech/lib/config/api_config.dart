import 'package:flutter/foundation.dart';

String get apiBaseUrl {
  if (kIsWeb) {
    return 'http://localhost:8000';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:8000';
    case TargetPlatform.iOS:
      return 'http://127.0.0.1:8000';
    default:
      return 'http://192.168.1.11:8000';
  }
}

String apiUrl(String path) => '$apiBaseUrl$path';

String wsNotificationsUrl(String jwt) =>
    'wss://pmg-es-2025-2-ti5-6904100-kontatech.onrender.com/ws/notifications?token=$jwt';