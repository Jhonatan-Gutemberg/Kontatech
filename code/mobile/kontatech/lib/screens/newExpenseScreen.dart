import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necessário para FilteringTextInputFormatter

// 1. REMOVA O 'http.dart' - O SERVIÇO CUIDARÁ DISSO
// import 'package:http/http.dart' as http;

// 2. ADICIONE OS IMPORTS DO SEU SERVIÇO E STORAGE
import 'package:kontatech/services/expense_service.dart';
import 'package:kontatech/services/group_service.dart';
import 'package:kontatech/utils/secure_storage.dart';

class _MemberAmount {
  final String id;
  final String label;
  final String email;
  bool selected;
  final TextEditingController controller;

  _MemberAmount({
    required this.id,
    required this.label,
    required this.email,
    bool selected = false,
    double initialAmount = 0.0,
  })  : selected = selected,
        controller = TextEditingController(
            text: initialAmount > 0 ? initialAmount.toStringAsFixed(2) : '');
}

class NewExpenseScreen extends StatefulWidget {
  final String groupId;

  const NewExpenseScreen({super.key, required this.groupId});

  @override
  State<NewExpenseScreen> createState() => _NewExpenseScreenState();
}

class _NewExpenseScreenState extends State<NewExpenseScreen> {
  // Controllers para todos os campos
  final _tituloController = TextEditingController();
  final _valorController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _dateController = TextEditingController();

  // Estado de loading
  bool _isLoading = false;

  final List<_MemberAmount> _groupMembers = [];

  @override
  void initState() {
    super.initState();
    _loadGroupMembers();
  }

  Future<void> _loadGroupMembers() async {
    try {
      final groupData = await GroupService.getGroupById(widget.groupId);
      final rawMembers = (groupData?['membros'] as List<dynamic>? ?? []);
      if (mounted) {
        setState(() {
          _groupMembers.clear();
          for (final m in rawMembers) {
            final id = (m['usuario_id'] ?? '').toString();
            final nome = (m['nome'] ?? m['usuario_nome'] ?? '').toString();
            final email = (m['email'] ?? m['usuario_email'] ?? '').toString();
            final label = nome.isNotEmpty
                ? nome
                : (email.isNotEmpty ? email : (id.isNotEmpty ? id : 'Membro'));
            _groupMembers.add(
              _MemberAmount(id: id, label: label, email: email),
            );
          }
        });
      }
    } catch (_) {}
  }

  // 3. FUNÇÃO DE SALVAMENTO ATUALIZADA
  Future<void> _saveExpense() async {
    // === 1. Obter e Tratar os Dados ===
    final title = _tituloController.text.trim();
    final description = _descricaoController.text.trim();
    final dateDisplayed = _dateController.text.trim(); // Formato: YYYY/MM/DD

    // Tratamento do Valor
    final String standardizedValue = _valorController.text.replaceAll(',', '.');
    final double? totalValue = double.tryParse(standardizedValue);

    // Validação básica
    if (title.isEmpty ||
        totalValue == null ||
        totalValue <= 0 ||
        dateDisplayed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Preencha Título, Valor e Data corretamente!')),
      );
      return;
    }

    // Conversão da Data para o formato da API (YYYY-MM-DD)
    final dateForApi = dateDisplayed.replaceAll('/', '-');

    // 5. PEGAMOS O ID DO USUÁRIO REAL (do SecureStorage)
    final userId = await SecureStorage.getUserId(); // Você precisa criar esta função em secure_storage.dart

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro: Usuário não logado. Faça login novamente.')),
      );
      return;
    }

    // Seleção de membros e valores individuais
    final selected = _groupMembers.where((m) => m.selected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos um participante do grupo.')),
      );
      return;
    }

    final List<double> amounts = [];
    for (final m in selected) {
      final txt = m.controller.text.trim().replaceAll(',', '.');
      final val = double.tryParse(txt) ?? 0.0;
      amounts.add(double.parse(val.toStringAsFixed(2)));
    }

    final double sumAmounts = double.parse(amounts.fold(0.0, (a, b) => a + b).toStringAsFixed(2));
    final double totalFixed = double.parse(totalValue.toStringAsFixed(2));
    if (sumAmounts != totalFixed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A soma dos valores (${sumAmounts.toStringAsFixed(2)}) deve ser igual ao total (${totalFixed.toStringAsFixed(2)}).')),
      );
      return;
    }

    final divisao = [
      for (int i = 0; i < selected.length; i++)
        {
          "usuario_id": selected[i].id,
          "valor_devido": amounts[i],
        }
    ];

    // === 2. Montar o Corpo da Requisição (JSON Body) ===
    final Map<String, dynamic> requestBody = {
      "titulo": title,
      "descricao": description.isEmpty ? null : description,
      "valor_total": totalValue,
      "data": dateForApi,
      "grupo_id": widget.groupId,
      "divisao": divisao,
    };

    setState(() => _isLoading = true); // Inicia o indicador de carregamento

    // === 3. Fazer a Chamada POST via SERVICE ===
    try {
      // 7. USAR O ExpenseService
      //    (Ele já usa o token e a URL '10.0.2.2' corretos)
      final response = await ExpenseService.createExpense(
        expenseData: requestBody,
      );

      // === 4. Tratar a Resposta ===
      if (mounted) {
        // Sucesso é quando a resposta NÃO é nula e tem um 'id'
        if (response != null && response['id'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Despesa salva com sucesso!')),
          );
          Navigator.of(context).pop(response); // Retorna a despesa
        } else {
          // Erro (pega a mensagem 'detail' da API)
          final message = response?['detail'] ?? 'Erro desconhecido ao salvar.';

          // O Erro 401 "Credenciais inválidas" virá para cá
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Falha: $message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erro de conexão: $e')),
      );
    } finally {
      setState(() => _isLoading = false); // Finaliza o carregamento
    }
  }

  @override
  void dispose() {
    // Fazer o dispose de TODOS os controllers
    _tituloController.dispose();
    _valorController.dispose();
    _descricaoController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        // Salva a data no formato YYYY/MM/DD
        _dateController.text =
            "${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  double? _currentTotalInput() {
    final standardizedValue = _valorController.text.replaceAll(',', '.');
    final parsed = double.tryParse(standardizedValue);
    if (parsed == null) return null;
    return double.parse(parsed.toStringAsFixed(2));
  }

  double _selectedMembersSum() {
    double sum = 0;
    for (final member in _groupMembers.where((m) => m.selected)) {
      final value =
          double.tryParse(member.controller.text.replaceAll(',', '.')) ?? 0.0;
      sum += value;
    }
    return double.parse(sum.toStringAsFixed(2));
  }

  void _toggleMember(_MemberAmount member, bool selected) {
    setState(() {
      member.selected = selected;
      if (!selected) {
        member.controller.clear();
      }
    });
  }

  void _handleMemberValueChange(String _) {
    setState(() {});
  }

  Widget _buildSplitSummary() {
    final total = _currentTotalInput();
    if (total == null || total <= 0) {
      return const SizedBox.shrink();
    }
    final selectedSum = _selectedMembersSum();
    final remaining =
        double.parse((total - selectedSum).toStringAsFixed(2));
    final Color color =
        remaining == 0 ? Colors.green : (remaining < 0 ? Colors.orange : Colors.red);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo da divisão',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Total informado: R\$ ${total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            'Distribuído: R\$ ${selectedSum.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            'Restante: R\$ ${remaining.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard(_MemberAmount member, Color accentColor) {
    final initials = member.label.isNotEmpty
        ? member.label.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : '?';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: member.selected ? accentColor.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: member.selected ? accentColor : Colors.grey.shade200,
          width: member.selected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: accentColor.withOpacity(0.15),
                child: Text(
                  initials.toUpperCase(),
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (member.email.isNotEmpty)
                      Text(
                        member.email,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              Switch(
                value: member.selected,
                activeColor: accentColor,
                onChanged: (value) => _toggleMember(member, value),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: member.selected
                ? Padding(
                    key: ValueKey(member.id),
                    padding: const EdgeInsets.only(top: 16),
                    child: TextField(
                      controller: member.controller,
                      onChanged: _handleMemberValueChange,
                      decoration: InputDecoration(
                        labelText: 'Valor devido',
                        prefixText: 'R\$ ',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*[,.]?\d{0,2}'),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Responsáveis pelo pagamento',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Escolha os membros do grupo que participarão e defina quanto cada um deve.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        if (_groupMembers.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Carregando membros do grupo...',
              style: TextStyle(fontSize: 14),
            ),
          )
        else
          Column(
            children: _groupMembers
                .map((member) => _buildParticipantCard(member, primaryColor))
                .toList(),
          ),
        const SizedBox(height: 8),
        _buildSplitSummary(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'KontaTech',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.person), onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nova Despesa',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Preencha os campos para registrar sua despesa.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),

              // Atribuir os controllers aos TextFields
              const Text('Título da Despesa',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _tituloController, // ATRIBUÍDO
                decoration: const InputDecoration(hintText: 'Ex: Conta de Luz'),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 16),

              const Text('Valor',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _valorController, // ATRIBUÍDO
                decoration: const InputDecoration(hintText: 'R\$0,00'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*[,.]?\d{0,2}'),
                  ),
                ],
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              const Text('Descrição',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _descricaoController, // ATRIBUÍDO
                decoration:
                    const InputDecoration(hintText: 'Detalhes da despesa'),
                keyboardType: TextInputType.text,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              const Text('Data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _dateController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Selecione a Data (YYYY/MM/DD)',
                  suffixIcon:
                      Icon(Icons.calendar_today, color: Colors.grey.shade600),
                ),
                onTap: () => _selectDate(context),
              ),

              const SizedBox(height: 32),

              _buildParticipantsSection(primaryColor),

              // Atualizar o botão de salvar
              SizedBox(
                width: double.infinity,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _saveExpense, // CHAMA A FUNÇÃO DE SALVAR
                        child: const Text('Salvar Despesa'),
                      ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(foregroundColor: primaryColor),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
