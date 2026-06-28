import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kontatech/config/api_config.dart';
import 'package:kontatech/utils/secure_storage.dart';

class GroupService {
  static const String _baseUrl = apiBaseUrl;

  // ==================== CRIAR GRUPO ====================
  // Endpoint: POST /grupos/
  static Future<Map<String, dynamic>?> createGroup(String nome, String descricao) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/grupos/');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nome': nome,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print('Erro ao criar grupo: ${response.statusCode}');
        print('Corpo: ${utf8.decode(response.bodyBytes)}');
        return null;
      }
    } catch (e) {
      print('Exceção ao criar grupo: $e');
      return null;
    }
  }

  // ==================== LISTAR GRUPOS ====================
  // Endpoint: GET /grupos/
  static Future<List<dynamic>?> fetchGroups() async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/grupos/');

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
        print('Erro ao buscar grupos: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exceção ao buscar grupos: $e');
      return null;
    }
  }

  // ==================== OBTER GRUPO POR ID ====================
  // Endpoint: GET /grupos/{grupo_id}
  static Future<Map<String, dynamic>?> getGroupById(String groupId) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/grupos/$groupId');

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
        print('Erro ao buscar grupo: ${response.statusCode}');
        print('Resposta: ${utf8.decode(response.bodyBytes)}');
        return null;
      }
    } catch (e) {
      print('Exceção ao buscar grupo: $e');
      return null;
    }
  }

  // ==================== ATUALIZAR GRUPO ====================
  // Endpoint: PATCH /grupos/{grupo_id}
  static Future<Map<String, dynamic>?> updateGroup(String groupId, String nome) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/grupos/$groupId');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nome': nome,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print('Erro ao atualizar grupo: ${response.statusCode}');
        print('Resposta: ${utf8.decode(response.bodyBytes)}');
        return null;
      }
    } catch (e) {
      print('Exceção ao atualizar grupo: $e');
      return null;
    }
  }

  // ==================== EXCLUIR GRUPO ====================
  // Endpoint: DELETE /grupos/{grupo_id}
  // Retorna: true se sucesso, false se erro, ou String com mensagem de erro
  static Future<dynamic> deleteGroup(String groupId) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return 'Token não encontrado';
    }

    final url = Uri.parse('$_baseUrl/grupos/$groupId');

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
        print('Erro ao excluir grupo: ${response.statusCode}');
        print('Resposta: $body');
        // Retorna a mensagem de erro do servidor
        try {
          final decoded = jsonDecode(body);
          return decoded['detail'] ?? 'Erro ao excluir grupo';
        } catch (_) {
          return 'Erro ao excluir grupo';
        }
      }
    } catch (e) {
      print('Exceção ao excluir grupo: $e');
      return 'Erro de conexão';
    }
  }

  // ==================== ADICIONAR MEMBRO ====================
  // Endpoint: POST /grupos/{grupo_id}/membros
  // Payload: { "usuario_id": "uuid" }
  static Future<Map<String, dynamic>?> addMember(String groupId, String userId) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/grupos/$groupId/membros');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'usuario_id': userId,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print('Erro ao adicionar membro: ${response.statusCode}');
        print('Resposta: ${utf8.decode(response.bodyBytes)}');
        // Retorna o erro para tratamento na UI
        try {
          return jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          return {'detail': 'Erro ao adicionar membro'};
        }
      }
    } catch (e) {
      print('Exceção ao adicionar membro: $e');
      return null;
    }
  }

  // ==================== PROMOVER ADMIN ====================
  // Endpoint: POST /grupos/{grupo_id}/admins
  // Payload: { "usuario_id": "uuid" }
  static Future<Map<String, dynamic>?> promoteAdmin(String groupId, String userId) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/grupos/$groupId/admins');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'usuario_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print('Erro ao promover admin: ${response.statusCode}');
        print('Resposta: ${utf8.decode(response.bodyBytes)}');
        try {
          return jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          return {'detail': 'Erro ao promover admin'};
        }
      }
    } catch (e) {
      print('Exceção ao promover admin: $e');
      return null;
    }
  }
}
