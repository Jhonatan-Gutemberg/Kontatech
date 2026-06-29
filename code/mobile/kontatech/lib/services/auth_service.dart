import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kontatech/config/api_config.dart';
import '../utils/secure_storage.dart';

class AuthService {
  static String get baseUrl => apiBaseUrl;

  static Future<String?> login(String email, String password) async {
    final url = Uri.parse(apiUrl('/auth/login'));

    try {
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

      // Log response for debugging
      print('AuthService.login → status: ${response.statusCode}');
      print('AuthService.login → body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token'] as String?;
        final userId = data['user_id']?.toString();

        if (token != null && token.isNotEmpty) {
          await SecureStorage.saveToken(token);
          if (userId != null && userId.isNotEmpty) {
            await SecureStorage.saveUserId(userId);
          }
          return null;
        }

        print('AuthService.login → access_token ausente na resposta');
        return 'Resposta do backend inválida: access_token ausente';
      } else {
        print('AuthService.login → erro: ${response.statusCode} → ${response.body}');
        return 'Falha no login: servidor retornou ${response.statusCode}';
      }
    } catch (e) {
      print('AuthService.login → exceção de rede: $e');
      return 'Falha de conexão com o backend: $e';
    }
  }

  static Future<bool> register(String nome, String email, String senha) async {
    final url = Uri.parse(apiUrl('/auth/register'));

    try {
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
    } catch (e) {
      print('AuthService.register → exceção de rede: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    await SecureStorage.deleteToken();
  }
}
