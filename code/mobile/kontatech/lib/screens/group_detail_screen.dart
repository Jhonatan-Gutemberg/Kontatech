import 'package:flutter/material.dart';
import 'package:kontatech/services/group_service.dart';
import 'package:kontatech/services/user_service.dart';
import 'package:kontatech/screens/expense_list_screen.dart';
import 'package:kontatech/screens/wishlist_screen.dart';
import 'package:kontatech/utils/secure_storage.dart';

class GroupDetailScreen extends StatefulWidget {
  static const routeName = '/group-detail';
  final String groupId;
  final String? initialGroupName;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    this.initialGroupName,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  Map<String, dynamic>? _group;
  bool _isLoading = true;
  String? _currentUserId;
  bool _isAdmin = false;
  bool _isOriginalAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Obtém o ID do usuário logado
    _currentUserId = await SecureStorage.getUserId();
    
    // Carrega os dados do grupo
    final groupData = await GroupService.getGroupById(widget.groupId);
    
    if (mounted) {
      setState(() {
        _group = groupData;
        _isLoading = false;
        
        if (_group != null && _currentUserId != null) {
          // Verifica se o usuário atual é admin original
          _isOriginalAdmin = _group!['administrador_id'] == _currentUserId;
          
          // Verifica se o usuário atual é admin (qualquer admin)
          final membros = _group!['membros'] as List<dynamic>? ?? [];
          for (var membro in membros) {
            if (membro['usuario_id'] == _currentUserId) {
              _isAdmin = membro['is_admin'] == true;
              break;
            }
          }
        }
      });
    }
  }

  // ==================== EDITAR GRUPO ====================
  void _showEditDialog() {
    final nomeController = TextEditingController(text: _group?['nome'] ?? '');
    // Captura o ScaffoldMessenger ANTES de abrir o dialog
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar Grupo'),
        content: TextField(
          controller: nomeController,
          decoration: const InputDecoration(
            labelText: 'Nome do Grupo',
            hintText: 'Digite o novo nome',
          ),
          autofocus: true,
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
              
              final novoNome = nomeController.text.trim();
              Navigator.pop(dialogContext);
              
              final result = await GroupService.updateGroup(
                widget.groupId,
                novoNome,
              );
              
              if (result != null && result['id'] != null) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Grupo atualizado com sucesso!'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadData(); // Recarrega os dados
              } else {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(result?['detail']?.toString() ?? 'Erro ao atualizar grupo'),
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

  // ==================== EXCLUIR GRUPO ====================
  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Grupo'),
        content: Text(
          'Tem certeza que deseja excluir o grupo "${_group?['nome']}"?\n\n'
          'Esta ação não pode ser desfeita.',
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
              
              final result = await GroupService.deleteGroup(widget.groupId);
              
              if (result == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Grupo excluído com sucesso!'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context, true); // Volta e indica que houve alteração
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result is String ? result : 'Erro ao excluir grupo'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==================== ADICIONAR MEMBRO ====================
  void _showAddMemberDialog() {
    final emailController = TextEditingController();
    bool isSearching = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adicionar Membro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Digite o email do usuário que deseja adicionar ao grupo:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email do Usuário',
                  hintText: 'exemplo@email.com',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !isSearching,
              ),
              if (isSearching) ...[
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Buscando usuário...'),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSearching ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isSearching ? null : () async {
                if (emailController.text.trim().isEmpty ||
                    !emailController.text.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Digite um email válido')),
                  );
                  return;
                }
                
                setDialogState(() => isSearching = true);
                
                // Buscar usuário por email
                final userResult = await UserService.getUserByEmail(
                  emailController.text.trim(),
                );
                
                if (userResult == null) {
                  setDialogState(() => isSearching = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erro de conexão'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                if (userResult['detail'] != null) {
                  setDialogState(() => isSearching = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(userResult['detail'].toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                // Adicionar membro ao grupo
                final result = await GroupService.addMember(
                  widget.groupId,
                  userResult['id'].toString(),
                );
                
                Navigator.pop(context);
                
                if (result != null && result['id'] != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${userResult['nome']} adicionado ao grupo!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadData();
                } else {
                  final errorMsg = result?['detail'] ?? 'Erro ao adicionar membro';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMsg.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PROMOVER ADMIN ====================
  void _showPromoteAdminDialog(Map<String, dynamic> membro) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Promover a Admin'),
        content: Text(
          'Deseja promover "${membro['nome'] ?? membro['email'] ?? 'este usuário'}" '
          'a administrador do grupo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final result = await GroupService.promoteAdmin(
                widget.groupId,
                membro['usuario_id'],
              );
              
              if (result != null && result['id'] != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Usuário promovido a admin!'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadData();
              } else {
                final errorMsg = result?['detail'] ?? 'Erro ao promover admin';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMsg),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Promover'),
          ),
        ],
      ),
    );
  }

  // ==================== NAVEGAR PARA DESPESAS ====================
  void _navigateToExpenses() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpensesListScreen(
          groupId: widget.groupId,
          groupName: _group?['nome'],
        ),
      ),
    );
  }

  // ==================== NAVEGAR PARA WISHLIST ====================
  void _navigateToWishlist() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WishlistScreen(
          groupId: widget.groupId,
          groupName: _group?['nome'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_group?['nome'] ?? widget.initialGroupName ?? 'Detalhes do Grupo'),
        actions: [
          if (_isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showEditDialog,
              tooltip: 'Editar grupo',
            ),
          ],
          if (_isOriginalAdmin) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteDialog,
              tooltip: 'Excluir grupo',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _group == null
              ? const Center(
                  child: Text(
                    'Erro ao carregar grupo',
                    style: TextStyle(color: Colors.red),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ===== CARD DE INFORMAÇÕES =====
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: primaryColor.withOpacity(0.2),
                                      child: Icon(
                                        Icons.group,
                                        size: 30,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _group!['nome'] ?? 'Sem nome',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${(_group!['membros'] as List?)?.length ?? 0} membro(s)',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // ===== BOTÕES DE AÇÃO =====
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _navigateToExpenses,
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('Despesas'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _navigateToWishlist,
                                icon: const Icon(Icons.candlestick_chart),
                                label: const Text('Ações'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // ===== SEÇÃO DE MEMBROS =====
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Membros',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_isAdmin)
                              TextButton.icon(
                                onPressed: _showAddMemberDialog,
                                icon: const Icon(Icons.person_add, size: 20),
                                label: const Text('Adicionar'),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // ===== LISTA DE MEMBROS =====
                        ..._buildMembersList(),
                      ],
                    ),
                  ),
                ),
    );
  }

  List<Widget> _buildMembersList() {
    final membros = _group?['membros'] as List<dynamic>? ?? [];
    
    if (membros.isEmpty) {
      return [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nenhum membro encontrado'),
          ),
        ),
      ];
    }
    
    return membros.map((membro) {
      final isMembroAdmin = membro['is_admin'] == true;
      final isOriginal = membro['usuario_id'] == _group?['administrador_id'];
      final isCurrentUser = membro['usuario_id'] == _currentUserId;
      
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isMembroAdmin 
                ? Colors.amber.withOpacity(0.2) 
                : Colors.grey.withOpacity(0.2),
            child: Icon(
              isMembroAdmin ? Icons.admin_panel_settings : Icons.person,
              color: isMembroAdmin ? Colors.amber[700] : Colors.grey[600],
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  membro['nome'] ?? membro['email'] ?? 'Usuário',
                  style: TextStyle(
                    fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isCurrentUser)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Você',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            membro['email'] ?? '',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOriginal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Criador',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (isMembroAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              // Botão de promover (apenas para admin original e se não for admin)
              if (_isOriginalAdmin && !isMembroAdmin && !isCurrentUser)
                IconButton(
                  icon: const Icon(Icons.arrow_upward, color: Colors.green),
                  onPressed: () => _showPromoteAdminDialog(membro),
                  tooltip: 'Promover a Admin',
                ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
