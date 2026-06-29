import 'package:flutter/foundation.dart';

String get apiBaseUrl {
  // URL oficial de produção gerada pelo Render
  return 'https://kontatech-backend.onrender.com';
}

String apiUrl(String path) {
  String base = apiBaseUrl;
  if (!base.endsWith('/')) {
    base = '$base/';
  }
  String cleanPath = path.startsWith('/') ? path.substring(1) : path;
  
  return '$base$cleanPath';
}

String wsNotificationsUrl(String jwt) {
  if (apiBaseUrl.contains('onrender.com')) {
    return 'wss://kontatech-backend.onrender.com/ws/notifications?token=$jwt';
  }
  
  if (kIsWeb) {
    return 'ws://localhost:8000/ws/notifications?token=$jwt';
  }
  
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'ws://10.0.2.2:8000/ws/notifications?token=$jwt';
    case TargetPlatform.iOS:
      return 'ws://127.0.0.1:8000/ws/notifications?token=$jwt';
    default:
      return 'ws://localhost:8000/ws/notifications?token=$jwt';
  }
}