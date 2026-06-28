import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kontatech/services/expense_service.dart';
import 'package:kontatech/utils/secure_storage.dart';

class ExpenseDetailScreen extends StatefulWidget {
  static const routeName = '/expense-detail';
  final String expenseId;
  final String? initialTitle;

  const ExpenseDetailScreen({
    super.key,
    required this.expenseId,
    this.initialTitle,
  });

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  Map<String, dynamic>? _expense;
  bool _isLoading = true;
  String? _currentUserId;
  bool _isPagador = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    _currentUserId = await SecureStorage.getUserId();
    final expenseData = await ExpenseService.getExpenseById(widget.expenseId);

    if (mounted) {
      setState(() {
        _expense = expenseData;
        _isLoading = false;

        if (_expense != null && _currentUserId != null) {
          _isPagador = _expense!['pagador_id'] == _currentUserId;
        }
      });
    }
  }

  // ==================== EDITAR DESPESA ====================
  void _showEditDialog() {
    final tituloController = TextEditingController(text: _expense?['titulo'] ?? '');
    final descricaoController = TextEditingController(text: _expense?['descricao'] ?? '');
    final valorController = TextEditingController(
      text: _getValorTotal().toStringAsFixed(2).replaceAll('.', ','),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Despesa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ex: Conta de Luz',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  hintText: 'Detalhes da despesa',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: valorController,
                decoration: const InputDecoration(
                  labelText: 'Valor Total (R\$)',
                  prefixText: 'R\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,2}')),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (tituloController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('O título não pode ser vazio')),
                );
                return;
              }

              final valorText = valorController.text.replaceAll(',', '.');
              final valor = double.tryParse(valorText);
              if (valor == null || valor <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Digite um valor válido')),
                );
                return;
              }

              Navigator.pop(context);

              final updateData = <String, dynamic>{};
              
              if (tituloController.text.trim() != _expense?['titulo']) {
                updateData['titulo'] = tituloController.text.trim();
              }
              if (descricaoController.text.trim() != (_expense?['descricao'] ?? '')) {
                updateData['descricao'] = descricaoController.text.trim().isEmpty 
                    ? null 
                    : descricaoController.text.trim();
              }
              if (valor != _getValorTotal()) {
                updateData['valor_total'] = valor;
              }

              if (updateData.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nenhuma alteração detectada')),
                );
                return;
              }

              final result = await ExpenseService.updateExpense(
                widget.expenseId,
                updateData,
              );

              if (result != null && result['id'] != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Despesa atualizada com sucesso!'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadData();
              } else {
                final errorMsg = result?['detail'] ?? 'Erro ao atualizar despesa';
                ScaffoldMessenger.of(context).showSnackBar(
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

  // ==================== EXCLUIR DESPESA ====================
  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Despesa'),
        content: Text(
          'Tem certeza que deseja excluir "${_expense?['titulo']}"?\n\n'
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

              final success = await ExpenseService.deleteExpense(widget.expenseId);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Despesa excluída com sucesso!'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context, true); // Volta e indica que houve alteração
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Erro ao excluir despesa'),
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

  double _getValorTotal() {
    final valor = _expense?['valor_total'];
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? '0') ?? 0.0;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Sem data';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_expense?['titulo'] ?? widget.initialTitle ?? 'Detalhe da Despesa'),
        actions: [
          if (_isPagador) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showEditDialog,
              tooltip: 'Editar despesa',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteDialog,
              tooltip: 'Excluir despesa',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expense == null
              ? const Center(
                  child: Text(
                    'Erro ao carregar despesa',
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
                        // ===== CARD PRINCIPAL =====
                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Título
                                Text(
                                  _expense!['titulo'] ?? 'Sem título',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Descrição
                                if (_expense!['descricao'] != null &&
                                    _expense!['descricao'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Text(
                                      _expense!['descricao'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),

                                const Divider(),
                                const SizedBox(height: 12),

                                // Valor Total
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.attach_money,
                                        color: Colors.green,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Valor Total',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          'R\$ ${_getValorTotal().toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Informações adicionais
                                _buildInfoRow(
                                  Icons.calendar_today,
                                  'Data',
                                  _formatDate(_expense!['data']),
                                ),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  Icons.person,
                                  'Pagador',
                                  _expense!['nome_pagador'] ?? 'Não informado',
                                  highlight: _isPagador,
                                  suffix: _isPagador ? ' (Você)' : null,
                                ),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  Icons.group,
                                  'Grupo',
                                  _expense!['nome_grupo'] ?? 'Sem grupo',
                                ),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  Icons.access_time,
                                  'Criado em',
                                  _formatDate(_expense!['data_criacao']),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ===== SEÇÃO DIVISÃO =====
                        const Text(
                          'Divisão da Despesa',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        ..._buildDivisaoList(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {bool highlight = false, String? suffix}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value + (suffix ?? ''),
            style: TextStyle(
              fontSize: 14,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? Theme.of(context).primaryColor : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDivisaoList() {
    final divisao = _expense?['divisao'] as List<dynamic>? ?? [];

    if (divisao.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Nenhuma divisão registrada',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      ];
    }

    return divisao.map((item) {
      final valorDevido = item['valor_devido'];
      final valor = valorDevido is num
          ? valorDevido.toDouble()
          : double.tryParse(valorDevido?.toString() ?? '0') ?? 0.0;
      final isCurrentUser = item['usuario_id'] == _currentUserId;

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isCurrentUser
              ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
              : BorderSide.none,
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isCurrentUser
                ? Theme.of(context).primaryColor.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            child: Icon(
              Icons.person,
              color: isCurrentUser
                  ? Theme.of(context).primaryColor
                  : Colors.grey[600],
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item['nome_usuario'] ?? 'Usuário',
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
          trailing: Text(
            'R\$ ${valor.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isCurrentUser ? Colors.red : Colors.black87,
            ),
          ),
        ),
      );
    }).toList();
  }
}
