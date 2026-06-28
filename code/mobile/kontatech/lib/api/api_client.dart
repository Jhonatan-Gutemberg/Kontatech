import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  String? _token;

  ApiClient({required this.baseUrl});

  void setToken(String token) => _token = token;
  void clearToken() => _token = null;

  Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    return headers;
  }

  Future<dynamic> _handleResponse(http.Response res) async {
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception('API error ${res.statusCode}: ${res.body}');
  }

  // Auth
  Future<dynamic> register(Map<String, dynamic> payload) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/register'),
        headers: _headers(), body: jsonEncode(payload));
    return _handleResponse(res);
  }

  Future<dynamic> login(Map<String, dynamic> payload) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/login'),
        headers: _headers(), body: jsonEncode(payload));
    return _handleResponse(res);
  }

  // Users
  Future<List<dynamic>> listUsers() async {
    final res = await http.get(Uri.parse('$baseUrl/usuarios/'), headers: _headers());
    return List.from(await _handleResponse(res));
  }

  Future<dynamic> getUserById(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/usuarios/$id'), headers: _headers());
    return _handleResponse(res);
  }

  Future<dynamic> getUserByEmail(String email) async {
    final res = await http.get(Uri.parse('$baseUrl/usuarios/email/$email'), headers: _headers());
    return _handleResponse(res);
  }

  Future<dynamic> updateUser(String id, Map<String, dynamic> payload, {bool patch = true}) async {
    final uri = Uri.parse('$baseUrl/usuarios/$id');
    final res = patch
        ? await http.patch(uri, headers: _headers(), body: jsonEncode(payload))
        : await http.put(uri, headers: _headers(), body: jsonEncode(payload));
    return _handleResponse(res);
  }

  Future<void> deleteUser(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/usuarios/$id'), headers: _headers());
    await _handleResponse(res);
  }

  // Groups
  Future<dynamic> createGroup(Map<String, dynamic> payload) async {
    final res = await http.post(Uri.parse('$baseUrl/grupos/'), headers: _headers(), body: jsonEncode(payload));
    return _handleResponse(res);
  }

  Future<List<dynamic>> listGroups() async {
    final res = await http.get(Uri.parse('$baseUrl/grupos/'), headers: _headers());
    return List.from(await _handleResponse(res));
  }

  Future<dynamic> getGroup(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/grupos/$id'), headers: _headers());
    return _handleResponse(res);
  }

  Future<dynamic> updateGroup(String id, Map<String, dynamic> payload, {bool patch = true}) async {
    final uri = Uri.parse('$baseUrl/grupos/$id');
    final res = patch
        ? await http.patch(uri, headers: _headers(), body: jsonEncode(payload))
        : await http.put(uri, headers: _headers(), body: jsonEncode(payload));
    return _handleResponse(res);
  }

  Future<void> deleteGroup(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/grupos/$id'), headers: _headers());
    await _handleResponse(res);
  }

  Future<dynamic> addMember(String groupId, Map<String, dynamic> payload) async {
    final res = await http.post(Uri.parse('$baseUrl/grupos/$groupId/membros'), headers: _headers(), body: jsonEncode(payload));
    return _handleResponse(res);
  }

  Future<dynamic> promoteAdmin(String groupId, Map<String, dynamic> payload) async {
    final res = await http.post(Uri.parse('$baseUrl/grupos/$groupId/admins'), headers: _headers(), body: jsonEncode(payload));
    return _handleResponse(res);
  }

  // Expenses
  Future<dynamic> createExpense(Map<String, dynamic> payload) async {
    final res = await http.post(Uri.parse('$baseUrl/despesas/'), headers: _headers(), body: jsonEncode(payload));
    return _handleResponse(res);
  }

  Future<dynamic> getExpense(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/despesas/$id'), headers: _headers());
    return _handleResponse(res);
  }

  Future<List<dynamic>> listExpensesByGroup(String groupId) async {
    final res = await http.get(Uri.parse('$baseUrl/despesas/grupos/$groupId/despesas'), headers: _headers());
    return List.from(await _handleResponse(res));
  }

  Future<dynamic> updateExpense(String id, Map<String, dynamic> payload) async {
    final res = await http.put(Uri.parse('$baseUrl/despesas/$id'), headers: _headers(), body: jsonEncode(payload));
    return _handleResponse(res);
  }

  Future<void> deleteExpense(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/despesas/$id'), headers: _headers());
    await _handleResponse(res);
  }

  // Wishlist
  Future<dynamic> createWishlistItem(Map<String, dynamic> payload) async {
    final res = await http.post(Uri.parse('$baseUrl/wishlist/'), headers: _headers(), body: jsonEncode(payload));
    return _handleResponse(res);
  }

  Future<List<dynamic>> listWishlistByGroup(String groupId) async {
    final res = await http.get(Uri.parse('$baseUrl/wishlist/grupo/$groupId'), headers: _headers());
    return List.from(await _handleResponse(res));
  }

  Future<void> deleteWishlistItem(String itemId) async {
    final res = await http.delete(Uri.parse('$baseUrl/wishlist/$itemId'), headers: _headers());
    await _handleResponse(res);
  }

  // Notifications (debug publish)
  Future<dynamic> debugPublishNotification(Map<String, dynamic> payload) async {
    final res = await http.post(Uri.parse('$baseUrl/debug/notifications'), headers: _headers(), body: jsonEncode(payload));
    return _handleResponse(res);
  }
}