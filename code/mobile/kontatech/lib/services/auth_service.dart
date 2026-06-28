import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kontatech/config/api_config.dart';
import '../utils/secure_storage.dart';

class AuthService {
  static const String baseUrl = apiBaseUrl;

  static Future<bool> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'username': email,
        'password': password,
      },
    );


    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'];
      final userId = data['user_id'];
      await SecureStorage.saveToken(token);
      await SecureStorage.saveUserId(userId);
      return true;
    } else {
      return false;
    }
  }

  static Future<bool> register(String nome, String email, String senha) async {
    final url = Uri.parse('$baseUrl/auth/register');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'nome': nome,
        'email': email,
        'senha': senha,
      }),
    );

    if (response.statusCode == 201) {
      return true;
    } else {
      print('Erro no registro: ${response.statusCode} → ${response.body}');
      return false;
    }
  }

  static Future<void> logout() async {
    await SecureStorage.deleteToken();
  }
}
