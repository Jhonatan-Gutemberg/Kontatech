import 'package:flutter/foundation.dart';

String get apiBaseUrl {
  return 'https://kontatech-backend.onrender.com';
}

// Tratamento de segurança para garantir que a barra separadora exista e não duplique
String apiUrl(String path) {
  String base = apiBaseUrl;
  if (!base.endsWith('/')) {
    base = '$base/';
  }
  String cleanPath = path.startsWith('/') ? path.substring(1) : path;
  
  return '$base$cleanPath';
}

String wsNotificationsUrl(String jwt) {
  // Ajustado para o domínio correto e usando wss:// (seguro) exigido em produção
  return 'wss://kontatech-backend.onrender.com/ws/notifications?token=$jwt';
}