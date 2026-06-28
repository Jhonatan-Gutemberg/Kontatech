import 'package:flutter/material.dart';
import 'package:kontatech/services/user_service.dart';
import 'package:kontatech/services/auth_service.dart';
import 'package:kontatech/utils/secure_storage.dart';
import 'package:kontatech/screens/loginScreen.dart';

class ProfileScreen extends StatefulWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    _userId = await SecureStorage.getUserId();
    final userData = await UserService.getCurrentUser();

    if (mounted) {
      setState(() {
        _user = userData;
        _isLoading = false;
      });
    }
  }

  // ==================== EDITAR PERFIL ====================
  void _showEditDialog() {
    final nomeController = TextEditingController(text: _user?['nome'] ?? '');
    final emailController = TextEditingController(text: _user?['email'] ?? '');
    // Captura o ScaffoldMessenger ANTES de abrir o dialog
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar Perfil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Seu nome completo',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'seu@email.com',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nomeController.text.trim().isEmpty) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('O nome não pode ser vazio')),
                );
                return;
              }

              if (emailController.text.trim().isEmpty ||
                  !emailController.text.contains('@')) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Digite um email válido')),
                );
                return;
              }

              String? novoNome;
              String? novoEmail;

              if (nomeController.text.trim() != _user?['nome']) {
                novoNome = nomeController.text.trim();
              }
              if (emailController.text.trim() != _user?['email']) {
                novoEmail = emailController.text.trim();
              }

              if (novoNome == null && novoEmail == null) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Nenhuma alteração detectada')),
                );
                return;
              }

              Navigator.pop(dialogContext);

              final result = await UserService.updateUser(
                _userId!,
                nome: novoNome,
                email: novoEmail,
              );

              if (result != null && result['id'] != null) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Perfil atualizado com sucesso!'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadProfile();
              } else {
                final errorMsg = result?['detail'] ?? 'Erro ao atualizar perfil';
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(errorMsg.toString()),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  // ==================== EXCLUIR CONTA ====================
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Excluir Conta'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tem certeza que deseja excluir sua conta?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('Esta ação irá:'),
            SizedBox(height: 8),
            Text('• Remover você de todos os grupos'),
            Text('• Excluir suas participações em divisões'),
            Text('• Apagar permanentemente seus dados'),
            SizedBox(height: 12),
            Text(
              'Esta ação não pode ser desfeita!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);

              final result = await UserService.deleteUser(_userId!);

              if (result == true) {
                // Limpa o storage e volta para login
                await SecureStorage.deleteToken();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Conta excluída com sucesso'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Navega para tela de login removendo todo histórico
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result is String ? result : 'Erro ao excluir conta'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Excluir Conta', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==================== LOGOUT ====================
  void _logout() async {
    await AuthService.logout();
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    final Widget bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _user == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'Erro ao carregar perfil',
                      style: TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadProfile,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadProfile,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: primaryColor.withOpacity(0.1),
                                child: Text(
                                  _getInitials(_user!['nome'] ?? ''),
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _user!['nome'] ?? 'Sem nome',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.email, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    _user!['email'] ?? 'Sem email',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.badge, color: Colors.blue),
                              ),
                              title: const Text('ID do Usuário'),
                              subtitle: Text(
                                _userId ?? 'N/A',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.logout, color: Colors.orange),
                              ),
                              title: const Text('Sair da conta'),
                              subtitle: const Text('Fazer logout do aplicativo'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _logout,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.delete_forever, color: Colors.red),
                              ),
                              title: const Text(
                                'Excluir conta',
                                style: TextStyle(color: Colors.red),
                              ),
                              subtitle: const Text('Remover permanentemente sua conta'),
                              trailing: const Icon(Icons.chevron_right, color: Colors.red),
                              onTap: _showDeleteAccountDialog,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              );

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Meu Perfil'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _user != null ? _showEditDialog : null,
                  tooltip: 'Editar perfil',
                ),
              ],
            ),
      body: Column(
        children: [
          if (widget.embedded)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _user != null ? _showEditDialog : null,
                tooltip: 'Editar perfil',
              ),
            ),
          Expanded(child: bodyContent),
        ],
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

