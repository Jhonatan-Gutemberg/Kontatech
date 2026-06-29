import 'package:flutter/foundation.dart';

String get apiBaseUrl {
  return 'https://kontatech-backend.onrender.com';
}

String apiUrl(String path) => '$apiBaseUrl$path';

String wsNotificationsUrl(String jwt) =>
    'wss://pmg-es-2025-2-ti5-6904100-kontatech.onrender.com/ws/notifications?token=$jwt';