import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kontatech/utils/secure_storage.dart';
import 'package:kontatech/config/api_config.dart';

class ExpenseService {
  // 1. CORREÇÃO: Removendo o /api/v1 para corresponder ao seu group_service
  // A URL base correta é esta, de acordo com seu código funcional:
  static String get _baseUrl => apiBaseUrl;

  // Função para CRIAR uma nova despesa
  // Ela agora recebe o Map<String, dynamic> completo, o que é mais robusto
  static Future<Map<String, dynamic>?> createExpense({
    required Map<String, dynamic> expenseData,
  }) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    // 2. Endpoint de criação de despesa
    final url = Uri.parse('$_baseUrl/despesas/');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(expenseData), // Envia o JSON completo
      );

      // 3. Tratamento de Respostas
      if (response.statusCode == 201) { // 201 - Created
        return jsonDecode(utf8.decode(response.bodyBytes)); // Retorna a despesa criada
      } else {
        // Imprime o erro para debug
        print('Erro ao criar despesa: ${response.statusCode}');
        print('URL: $url');
        print('Token: Bearer ${token.substring(0, 10)}...'); // Apenas parte do token
        print('Corpo enviado: ${jsonEncode(expenseData)}');
        print('Resposta do servidor: ${utf8.decode(response.bodyBytes)}');
        
        // Retorna o corpo do erro para a tela
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      print('Exceção ao criar despesa: $e');
      return null;
    }
  }

  // Função para BUSCAR as despesas de um grupo específico
  // Endpoint correto: GET /despesas/grupos/{grupo_id}/despesas
  static Future<List<dynamic>?> fetchExpensesByGroup(String groupId) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/despesas/grupos/$groupId/despesas');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)); // Retorna a lista de despesas
      } else {
        print('Erro ao buscar despesas do grupo: ${response.statusCode}');
        print('URL: $url');
        print('Resposta do servidor: ${utf8.decode(response.bodyBytes)}');
        return null;
      }
    } catch (e) {
      print('Exceção ao buscar despesas do grupo: $e');
      return null;
    }
  }

  // Função para OBTER uma despesa específica pelo ID
  // Endpoint: GET /despesas/{despesa_id}
  static Future<Map<String, dynamic>?> getExpenseById(String expenseId) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/despesas/$expenseId');

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
        print('Erro ao buscar despesa: ${response.statusCode}');
        print('Resposta do servidor: ${utf8.decode(response.bodyBytes)}');
        return null;
      }
    } catch (e) {
      print('Exceção ao buscar despesa: $e');
      return null;
    }
  }

  // Função para ATUALIZAR uma despesa
  // Endpoint: PUT /despesas/{despesa_id}
  static Future<Map<String, dynamic>?> updateExpense(
      String expenseId, Map<String, dynamic> expenseData) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/despesas/$expenseId');

    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(expenseData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print('Erro ao atualizar despesa: ${response.statusCode}');
        print('Resposta do servidor: ${utf8.decode(response.bodyBytes)}');
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      print('Exceção ao atualizar despesa: $e');
      return null;
    }
  }

  // Função para EXCLUIR uma despesa
  // Endpoint: DELETE /despesas/{despesa_id}
  static Future<bool> deleteExpense(String expenseId) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return false;
    }

    final url = Uri.parse('$_baseUrl/despesas/$expenseId');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        print('Erro ao excluir despesa: ${response.statusCode}');
        print('Resposta do servidor: ${utf8.decode(response.bodyBytes)}');
        return false;
      }
    } catch (e) {
      print('Exceção ao excluir despesa: $e');
      return false;
    }
  }
}
