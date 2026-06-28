import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  // salva o token
  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  // lê o token
  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  // apaga o token
  static Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
  }
  
  // salva o userID
  static Future<void> saveUserId(String id) async {
    await _storage.write(key: 'user_id', value: id);
  }

  // pega o userID
  static Future<String?> getUserId() async {
    return await _storage.read(key: 'user_id');
  }
  


}
