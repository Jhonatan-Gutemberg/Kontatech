import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kontatech/config/api_config.dart';
import 'package:kontatech/utils/secure_storage.dart';

class WishlistService {
  static const String _baseUrl = apiBaseUrl;

  // ==================== CRIAR ITEM NA WISHLIST ====================
  // Endpoint: POST /wishlist/
  // Payload: { "grupo_id": "uuid", "symbol": "AAPL", "preco_alvo": 150.00, "titulo": "...", "data_limite": "ISO8601" }
  static Future<Map<String, dynamic>?> createWishlistItem({
    required String groupId,
    required String symbol,
    required double precoAlvo,
    String? titulo,
    DateTime? dataLimite,
  }) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/wishlist/');

    final Map<String, dynamic> body = {
      'grupo_id': groupId,
      'symbol': symbol,
      'preco_alvo': precoAlvo,
    };
    
    if (titulo != null && titulo.isNotEmpty) {
      body['titulo'] = titulo;
    }
    
    if (dataLimite != null) {
      body['data_limite'] = dataLimite.toUtc().toIso8601String();
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print('Erro ao criar item na wishlist: ${response.statusCode}');
        print('Resposta: ${utf8.decode(response.bodyBytes)}');
        try {
          return jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          return {'detail': 'Erro ao criar ação monitorada'};
        }
      }
    } catch (e) {
      print('Exceção ao criar item na wishlist: $e');
      return null;
    }
  }

  // ==================== LISTAR WISHLIST DO GRUPO ====================
  // Endpoint: GET /wishlist/grupo/{grupo_id}
  static Future<List<dynamic>?> listWishlistByGroup(String groupId) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/wishlist/grupo/$groupId');

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
        print('Erro ao listar wishlist: ${response.statusCode}');
        print('Resposta: ${utf8.decode(response.bodyBytes)}');
        return null;
      }
    } catch (e) {
      print('Exceção ao listar wishlist: $e');
      return null;
    }
  }

  // ==================== DELETAR ITEM DA WISHLIST ====================
  // Endpoint: DELETE /wishlist/{item_id}
  static Future<bool> deleteWishlistItem(String itemId) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      print('Erro: Token de autenticação não encontrado.');
      return false;
    }

    final url = Uri.parse('$_baseUrl/wishlist/$itemId');

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
        print('Erro ao deletar item da wishlist: ${response.statusCode}');
        print('Resposta: ${utf8.decode(response.bodyBytes)}');
        return false;
      }
    } catch (e) {
      print('Exceção ao deletar item da wishlist: $e');
      return false;
    }
  }
}

