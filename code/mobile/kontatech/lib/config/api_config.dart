import 'package:flutter/foundation.dart';

String get apiBaseUrl {
  // URL oficial de produção gerada pelo Render
  return 'https://kontatech-backend.onrender.com';

  /*
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
  */
}

String apiUrl(String path) => '$apiBaseUrl$path';

String wsNotificationsUrl(String jwt) {
  // Identifica dinamicamente se estamos usando o Render em produção
  if (apiBaseUrl.contains('onrender.com')) {
    // Alinhado com a URL real e usando wss:// seguro para produção
    return 'wss://kontatech-backend.onrender.com/ws/notifications?token=$jwt';
  }
  
  // Fallback seguro para rodar localmente no celular físico ou emulador
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'ws://10.0.2.2:8000/ws/notifications?token=$jwt';
  }
  return 'ws://localhost:8000/ws/notifications?token=$jwt';
}