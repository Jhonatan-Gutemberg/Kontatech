import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kontatech/config/api_config.dart';
import 'package:kontatech/utils/secure_storage.dart';

class UserService {
  static const String _baseUrl = apiBaseUrl;

  // ==================== LISTAR USUÁRIOS ====================
  // Endpoint: GET /usuarios/
  static Future<List<dynamic>?> listUsers() async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/usuarios/');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print('Erro ao listar usuários: ${response.statusCode}');
        print('Resposta: ${utf8.decode(response.bodyBytes)}');
        return null;
      }
    } catch (e) {
      print('Exceção ao listar usuários: $e');
      return null;
    }
  }

  // ==================== OBTER USUÁRIO POR ID ====================
  // Endpoint: GET /usuarios/{usuario_id}
  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/usuarios/$userId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print('Erro ao obter usuário: ${response.statusCode}');
        print('Resposta: ${utf8.decode(response.bodyBytes)}');
        return null;
      }
    } catch (e) {
      print('Exceção ao obter usuário: $e');
      return null;
    }
  }

  // ==================== OBTER USUÁRIO POR EMAIL ====================
  // Endpoint: GET /usuarios/email/{email}
  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/usuarios/email/$email');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print('Erro ao obter usuário por email: ${response.statusCode}');
        print('Resposta: ${utf8.decode(response.bodyBytes)}');
        // Retorna o erro para tratamento na UI
        try {
          return jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          return {'detail': 'Usuário não encontrado'};
        }
      }
    } catch (e) {
      print('Exceção ao obter usuário por email: $e');
      return null;
    }
  }

  // ==================== ATUALIZAR USUÁRIO ====================
  // Endpoint: PATCH /usuarios/{usuario_id}
  static Future<Map<String, dynamic>?> updateUser(
    String userId, {
    String? nome,
    String? email,
    double? rendaMensal,
  }) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/usuarios/$userId');

    final body = <String, dynamic>{};
    if (nome != null) body['nome'] = nome;
    if (email != null) body['email'] = email;
    if (rendaMensal != null) body['renda_mensal'] = rendaMensal;

    if (body.isEmpty) {
      return {'detail': 'Nenhum campo para atualizar'};
    }

    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print('Erro ao atualizar usuário: ${response.statusCode}');
        print('Resposta: ${utf8.decode(response.bodyBytes)}');
        try {
          return jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          return {'detail': 'Erro ao atualizar usuário'};
        }
      }
    } catch (e) {
      print('Exceção ao atualizar usuário: $e');
      return null;
    }
  }

  // ==================== EXCLUIR USUÁRIO ====================
  // Endpoint: DELETE /usuarios/{usuario_id}
  static Future<dynamic> deleteUser(String userId) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return 'Token não encontrado';
    }

    final url = Uri.parse('$_baseUrl/usuarios/$userId');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 204) {
        return true;
      } else {
        final body = utf8.decode(response.bodyBytes);
        print('Erro ao excluir usuário: ${response.statusCode}');
        print('Resposta: $body');
        try {
          final decoded = jsonDecode(body);
          return decoded['detail'] ?? 'Erro ao excluir conta';
        } catch (_) {
          return 'Erro ao excluir conta';
        }
      }
    } catch (e) {
      print('Exceção ao excluir usuário: $e');
      return 'Erro de conexão';
    }
  }

  // ==================== OBTER USUÁRIO ATUAL ====================
  // Usa o ID armazenado no SecureStorage
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final userId = await SecureStorage.getUserId();
    if (userId == null) {
      print('Erro: ID do usuário não encontrado no storage.');
      return null;
    }
    return getUserById(userId);
  }
}

