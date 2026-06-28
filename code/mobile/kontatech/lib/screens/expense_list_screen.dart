import 'package:flutter/material.dart';
import 'package:kontatech/screens/newExpenseScreen.dart';
import 'package:kontatech/screens/expense_detail_screen.dart';
import 'package:kontatech/services/expense_service.dart';

class ExpensesListScreen extends StatefulWidget {
  final String groupId;
  final String? groupName;

  const ExpensesListScreen({
    super.key,
    required this.groupId,
    this.groupName,
  });

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  List<Map<String, dynamic>> _despesas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    setState(() => _isLoading = true);

    final expensesData = await ExpenseService.fetchExpensesByGroup(widget.groupId);

    if (mounted) {
      if (expensesData != null) {
        setState(() {
          _despesas = List<Map<String, dynamic>>.from(expensesData);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar despesas do grupo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToNewExpense() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewExpenseScreen(groupId: widget.groupId)),
    );

    // Se uma nova despesa foi retornada, recarrega a lista
    if (result != null) {
      _fetchExpenses();
    }
  }

  void _navigateToExpenseDetail(Map<String, dynamic> despesa) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseDetailScreen(
          expenseId: despesa['id'].toString(),
          initialTitle: despesa['titulo'],
        ),
      ),
    );

    // Se houve alteração (ex: despesa excluída ou editada), recarrega a lista
    if (result == true) {
      _fetchExpenses();
    }
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
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          widget.groupName != null
              ? 'Despesas • ${widget.groupName}'
              : 'Despesas do Grupo',
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _despesas.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _fetchExpenses,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                      itemCount: _despesas.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummarySection(primaryColor),
                              const SizedBox(height: 24),
                              Text(
                                'Despesas registradas',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        }

                        final despesa = _despesas[index - 1];
                        final highlight = index == 1;
                        return _buildExpenseCard(
                          despesa,
                          primaryColor,
                          highlight: highlight,
                        );
                      },
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToNewExpense,
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Nova despesa'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma despesa encontrada',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adicione a primeira despesa do grupo!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToNewExpense,
            icon: const Icon(Icons.add),
            label: const Text('Nova Despesa'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(Color primaryColor) {
    final double total = _despesas.fold<double>(
      0,
      (sum, item) => sum + (double.tryParse(item['valor_total'].toString()) ?? 0),
    );
    final double media = _despesas.isNotEmpty ? total / _despesas.length : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo do grupo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.groupName ?? 'Grupo selecionado',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _SummaryChip(
                label: 'Total acumulado',
                value: 'R\$ ${total.toStringAsFixed(2)}',
              ),
              const SizedBox(width: 16),
              _SummaryChip(
                label: 'Qtd. despesas',
                value: '${_despesas.length}',
              ),
              const SizedBox(width: 16),
              _SummaryChip(
                label: 'Ticket médio',
                value: 'R\$ ${media.toStringAsFixed(2)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(
    Map<String, dynamic> despesa,
    Color primaryColor, {
    bool highlight = false,
  }) {
    final valorTotal = despesa['valor_total'];
    final valor = valorTotal is num
        ? valorTotal.toDouble()
        : double.tryParse(valorTotal?.toString() ?? '0') ?? 0.0;

    final nomePagador = despesa['nome_pagador'] ?? 'Pagador não informado';
    final descricao = despesa['descricao'] ?? '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? primaryColor.withOpacity(0.5)
              : Colors.grey.shade100,
          width: highlight ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToExpenseDetail(despesa),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.receipt_long, color: primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        despesa['titulo'] ?? 'Despesa sem título',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      if (descricao.isNotEmpty)
                        Text(
                          descricao,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'R\$ ${valor.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.person_outline,
                  label: nomePagador,
                ),
                const SizedBox(width: 10),
                _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: _formatDate(despesa['data']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
