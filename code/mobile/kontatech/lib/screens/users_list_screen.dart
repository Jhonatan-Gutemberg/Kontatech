import 'package:flutter/material.dart';
import 'package:kontatech/services/user_service.dart';
import 'package:kontatech/screens/user_detail_screen.dart';
import 'package:kontatech/utils/secure_storage.dart';

class UsersListScreen extends StatefulWidget {
  static const routeName = '/users';
  
  /// Callback opcional quando um usuário é selecionado
  /// Útil para selecionar usuário ao adicionar membro a um grupo
  final Function(Map<String, dynamic> user)? onUserSelected;
  final bool selectionMode;

  const UsersListScreen({
    super.key,
    this.onUserSelected,
    this.selectionMode = false,
  });

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;
  String? _currentUserId;
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    _currentUserId = await SecureStorage.getUserId();
    final result = await UserService.listUsers();

    if (mounted) {
      setState(() {
        _users = result ?? [];
        _filteredUsers = _users;
        _isLoading = false;
      });

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar usuários'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          final nome = (user['nome'] ?? '').toString().toLowerCase();
          final email = (user['email'] ?? '').toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return nome.contains(searchLower) || email.contains(searchLower);
        }).toList();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredUsers = _users;
      }
    });
  }

  void _onUserTap(Map<String, dynamic> user) {
    if (widget.selectionMode && widget.onUserSelected != null) {
      widget.onUserSelected!(user);
      Navigator.pop(context, user);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserDetailScreen(
            userId: user['id'].toString(),
            initialName: user['nome'],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar por nome ou email...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: _filterUsers,
              )
            : Text(widget.selectionMode ? 'Selecionar Usuário' : 'Usuários'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? _buildEmptyState()
              : _filteredUsers.isEmpty
                  ? _buildNoResultsState()
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = Map<String, dynamic>.from(_filteredUsers[index]);
                          return _buildUserCard(user);
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum usuário encontrado',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
            label: const Text('Recarregar'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum resultado para "${_searchController.text}"',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _searchController.clear();
              _filterUsers('');
            },
            child: const Text('Limpar busca'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isCurrentUser = user['id'] == _currentUserId;
    final nome = user['nome'] ?? 'Sem nome';
    final email = user['email'] ?? 'Sem email';
    final primaryColor = Theme.of(context).primaryColor;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isCurrentUser
            ? BorderSide(color: primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isCurrentUser
              ? primaryColor.withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
          radius: 24,
          child: Text(
            _getInitials(nome),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isCurrentUser ? primaryColor : Colors.grey[700],
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                nome,
                style: TextStyle(
                  fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Você',
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.email, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  email,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        trailing: widget.selectionMode
            ? Icon(Icons.add_circle_outline, color: primaryColor)
            : const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => _onUserTap(user),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}
