import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kontatech/services/expense_service.dart';
import 'package:kontatech/services/group_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<_GroupOverview> _groupOverview = [];
  List<_ExpenseHighlight> _recentExpenses = [];
  double _totalAmount = 0;
  int _totalExpenses = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await GroupService.fetchGroups();
      if (!mounted) return;

      if (groups == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Não foi possível carregar os grupos.';
        });
        return;
      }

      final List<_GroupOverview> overview = [];
      final List<_ExpenseHighlight> recentExpenses = [];
      double totalAmount = 0;
      int totalExpenses = 0;

      for (final dynamic rawGroup in groups) {
        final String groupId = rawGroup['id'].toString();
        final String groupName = rawGroup['nome']?.toString() ?? 'Grupo';

        final expenses =
            await ExpenseService.fetchExpensesByGroup(groupId) ?? [];

        double groupTotal = 0;
        for (final dynamic expense in expenses) {
          final double value =
              double.tryParse(expense['valor_total']?.toString() ?? '') ?? 0;
          groupTotal += value;

          final DateTime date = _parseDate(expense['data']);
          recentExpenses.add(
            _ExpenseHighlight(
              title: expense['titulo']?.toString() ?? 'Despesa',
              groupName: groupName,
              amount: value,
              date: date,
            ),
          );
        }

        overview.add(
          _GroupOverview(
            id: groupId,
            name: groupName,
            expensesCount: expenses.length,
            totalAmount: groupTotal,
          ),
        );

        totalAmount += groupTotal;
        totalExpenses += expenses.length;
      }

      recentExpenses.sort((a, b) => b.date.compareTo(a.date));
      final highlights = recentExpenses.length > 5
          ? recentExpenses.sublist(0, 5)
          : recentExpenses;

      setState(() {
        _groupOverview = overview;
        _recentExpenses = highlights;
        _totalAmount = totalAmount;
        _totalExpenses = totalExpenses;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ocorreu um erro ao montar o dashboard.';
      });
    }
  }

  DateTime _parseDate(dynamic rawDate) {
    if (rawDate == null) return DateTime.now();
    try {
      return DateTime.parse(rawDate.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadDashboardData,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_groupOverview.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            _buildHeroSection(context),
            const SizedBox(height: 24),
            _buildEmptyState(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        children: [
          _buildHeroSection(context),
          const SizedBox(height: 24),
          _buildSummarySection(context),
          const SizedBox(height: 24),
          _buildGroupsSection(context),
          const SizedBox(height: 24),
          _buildRecentExpensesSection(context),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            offset: const Offset(0, 20),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        
        children: [
          Text(
            'Painel Financeiro',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Acompanhe a saúde financeira dos seus grupos e despesas.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _heroValue(
                title: 'Total geral',
                value: 'R\$ ${_totalAmount.toStringAsFixed(2)}',
              ),
              const SizedBox(width: 16),
              _heroValue(
                title: 'Despesas registradas',
                value: '$_totalExpenses',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroValue({required String title, required String value}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    final cards = [
      (
        'Grupos ativos',
        _groupOverview.length.toString(),
        Icons.group,
        Colors.indigo
      ),
      (
        'Maior grupo',
        _largestGroupName(),
        Icons.leaderboard,
        Colors.deepPurple
      ),
      (
        'Ticket médio',
        _ticketMedio(),
        Icons.paid,
        Colors.teal
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: cards
            .map(
              (card) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _SummaryCard(
                  icon: card.$3,
                  label: card.$1,
                  value: card.$2,
                  color: card.$4,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildGroupsSection(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final sortedGroups = [..._groupOverview]
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    final maxValue =
        sortedGroups.isEmpty ? 1 : sortedGroups.first.totalAmount.clamp(1, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Grupos em destaque', Icons.workspace_premium),
        const SizedBox(height: 12),
        ...sortedGroups.map((group) {
          final progress =
              max(0.05, (group.totalAmount / maxValue).clamp(0, 1).toDouble());
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primaryColor.withOpacity(0.1),
                      child: Icon(Icons.group, color: primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        group.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      'R\$ ${group.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  color: primaryColor,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(height: 8),
                Text(
                  '${group.expensesCount} despesa(s) registrada(s)',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecentExpensesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Últimas movimentações', Icons.history),
        const SizedBox(height: 12),
        if (_recentExpenses.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Text('Nenhuma despesa registrada recentemente.'),
          )
        else
          ..._recentExpenses.map(
            (expense) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          expense.groupName,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(expense.date),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'R\$ ${expense.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.explore_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'Você ainda não possui grupos registrados.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Crie seu primeiro grupo e visualize aqui um resumo visual das despesas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _largestGroupName() {
    if (_groupOverview.isEmpty) return '--';
    final sorted = [..._groupOverview]
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return sorted.first.name;
  }

  String _ticketMedio() {
    if (_totalExpenses == 0) return 'R\$ 0,00';
    final media = _totalAmount / _totalExpenses;
    return 'R\$ ${media.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _GroupOverview {
  final String id;
  final String name;
  final int expensesCount;
  final double totalAmount;

  _GroupOverview({
    required this.id,
    required this.name,
    required this.expensesCount,
    required this.totalAmount,
  });
}

class _ExpenseHighlight {
  final String title;
  final String groupName;
  final double amount;
  final DateTime date;

  _ExpenseHighlight({
    required this.title,
    required this.groupName,
    required this.amount,
    required this.date,
  });
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

