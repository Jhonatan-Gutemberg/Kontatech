import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kontatech/services/wishlist_service.dart';

/// Tela para adicionar uma nova ação ao monitoramento
/// O usuário define o símbolo da ação e o preço-alvo desejado
class CreateWishlistItemScreen extends StatefulWidget {
  static const routeName = '/create-wishlist';
  final String groupId;
  final String? groupName;

  const CreateWishlistItemScreen({
    super.key,
    required this.groupId,
    this.groupName,
  });

  @override
  State<CreateWishlistItemScreen> createState() => _CreateWishlistItemScreenState();
}

class _CreateWishlistItemScreenState extends State<CreateWishlistItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _symbolController = TextEditingController();
  final _precoAlvoController = TextEditingController();
  bool _isLoading = false;
  
  // Prazo limite
  bool _usarPrazo = false;
  String _tipoPrazo = 'horas'; // 'horas' ou 'dias'
  int _quantidadePrazo = 1;

  @override
  void dispose() {
    _tituloController.dispose();
    _symbolController.dispose();
    _precoAlvoController.dispose();
    super.dispose();
  }
  
  DateTime? _calcularDataLimite() {
    if (!_usarPrazo) return null;
    
    final now = DateTime.now();
    if (_tipoPrazo == 'horas') {
      return now.add(Duration(hours: _quantidadePrazo));
    } else {
      return now.add(Duration(days: _quantidadePrazo));
    }
  }
  
  String _formatarPrazoSelecionado() {
    if (_tipoPrazo == 'horas') {
      return '$_quantidadePrazo hora${_quantidadePrazo > 1 ? 's' : ''}';
    } else {
      return '$_quantidadePrazo dia${_quantidadePrazo > 1 ? 's' : ''}';
    }
  }
  
  Widget _buildPrazoTypeButton(String label, String tipo, IconData icon) {
    final isSelected = _tipoPrazo == tipo;
    return InkWell(
      onTap: () => setState(() {
        _tipoPrazo = tipo;
        _quantidadePrazo = 1; // Reset ao trocar tipo
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.orange : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.orange : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAtalhoButton(String label, int quantidade) {
    final isSelected = _quantidadePrazo == quantidade;
    return InkWell(
      onTap: () => setState(() => _quantidadePrazo = quantidade),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  void _showSymbolHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Símbolos de Ações'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Use o ticker/símbolo oficial da ação:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('🇺🇸 Ações americanas:', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('• AAPL - Apple'),
              Text('• MSFT - Microsoft'),
              Text('• GOOGL - Google/Alphabet'),
              Text('• AMZN - Amazon'),
              Text('• TSLA - Tesla'),
              Text('• META - Meta/Facebook'),
              Text('• NVDA - NVIDIA'),
              SizedBox(height: 12),
              Text('🇧🇷 Ações brasileiras:', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('• PETR4.SA - Petrobras'),
              Text('• VALE3.SA - Vale'),
              Text('• ITUB4.SA - Itaú'),
              Text('• BBDC4.SA - Bradesco'),
              SizedBox(height: 12),
              Text(
                'Nota: Os dados são fornecidos pelo Finnhub. '
                'Algumas ações podem não estar disponíveis.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Converte preço para double
    final precoText = _precoAlvoController.text.replaceAll(',', '.');
    final precoAlvo = double.tryParse(precoText);

    if (precoAlvo == null || precoAlvo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite um preço válido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final dataLimite = _calcularDataLimite();

    final result = await WishlistService.createWishlistItem(
      groupId: widget.groupId,
      symbol: _symbolController.text.trim(),
      precoAlvo: precoAlvo,
      titulo: _tituloController.text.trim().isNotEmpty 
          ? _tituloController.text.trim() 
          : null,
      dataLimite: dataLimite,
    );

    setState(() => _isLoading = false);

    if (result != null && result['id'] != null) {
      String mensagem = 'Ação adicionada ao monitoramento!';
      if (_usarPrazo) {
        mensagem += ' Prazo: ${_formatarPrazoSelecionado()}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Retorna true para indicar sucesso
    } else {
      final errorMsg = result?['detail'] ?? 'Erro ao adicionar ação';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'KontaTech',
          style: TextStyle(
            color: primaryColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header com ícone
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.candlestick_chart,
                        color: Colors.blue,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monitorar Ação',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          if (widget.groupName != null)
                            Text(
                              'Grupo: ${widget.groupName}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Defina um preço-alvo e receba uma notificação quando a ação atingir esse valor.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),

                // Campo: Symbol/Código (obrigatório)
                const Text(
                  'Símbolo da Ação *',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _symbolController,
                  decoration: InputDecoration(
                    hintText: 'Ex: AAPL, MSFT, GOOGL',
                    helperText: 'Use o ticker da ação (fonte: Finnhub)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.help_outline, size: 20),
                      onPressed: () => _showSymbolHelp(),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite o símbolo da ação';
                    }
                    if (value.trim().length < 1) {
                      return 'Símbolo inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Campo: Título (opcional)
                const Text(
                  'Descrição (opcional)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _tituloController,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Apple - Comprar na baixa',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 20),

                // Campo: Preço Alvo (obrigatório)
                const Text(
                  'Preço Alvo (USD) *',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _precoAlvoController,
                  decoration: const InputDecoration(
                    hintText: '150.00',
                    prefixText: '\$ ',
                    prefixIcon: Icon(Icons.flag_outlined),
                    helperText: 'Você será notificado quando o preço atingir este valor',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite o preço alvo';
                    }
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed == null || parsed <= 0) {
                      return 'Digite um valor válido maior que zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ==================== PRAZO LIMITE ====================
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Switch para ativar prazo
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Definir prazo limite',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Switch(
                            value: _usarPrazo,
                            onChanged: (value) => setState(() => _usarPrazo = value),
                            activeColor: Colors.orange,
                          ),
                        ],
                      ),
                      
                      if (_usarPrazo) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Se o preço não atingir o alvo até o prazo, você será notificado.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Tipo de prazo (horas ou dias)
                        Row(
                          children: [
                            Expanded(
                              child: _buildPrazoTypeButton(
                                'Horas',
                                'horas',
                                Icons.access_time,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildPrazoTypeButton(
                                'Dias',
                                'dias',
                                Icons.calendar_today,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Quantidade
                        Row(
                          children: [
                            Text(
                              'Monitorar por:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: _quantidadePrazo > 1
                                        ? () => setState(() => _quantidadePrazo--)
                                        : null,
                                    iconSize: 20,
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(),
                                  ),
                                  Container(
                                    width: 50,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$_quantidadePrazo',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () => setState(() => _quantidadePrazo++),
                                    iconSize: 20,
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _tipoPrazo == 'horas' 
                                  ? 'hora${_quantidadePrazo > 1 ? 's' : ''}'
                                  : 'dia${_quantidadePrazo > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        
                        // Atalhos rápidos
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_tipoPrazo == 'horas') ...[
                              _buildAtalhoButton('1h', 1),
                              _buildAtalhoButton('2h', 2),
                              _buildAtalhoButton('6h', 6),
                              _buildAtalhoButton('12h', 12),
                              _buildAtalhoButton('24h', 24),
                            ] else ...[
                              _buildAtalhoButton('1d', 1),
                              _buildAtalhoButton('2d', 2),
                              _buildAtalhoButton('3d', 3),
                              _buildAtalhoButton('7d', 7),
                              _buildAtalhoButton('30d', 30),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_down, color: Colors.teal[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Como funciona?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• O sistema monitora o preço da ação em tempo real\n'
                        '• Quando o preço de mercado ≤ preço alvo, você recebe uma notificação\n'
                        '${_usarPrazo ? '• Se o prazo expirar sem atingir o alvo, você também será notificado\n' : ''}'
                        '• Perfeito para encontrar oportunidades de compra!',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.teal[800],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Botão Salvar
                SizedBox(
                  width: double.infinity,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: _saveItem,
                          icon: const Icon(Icons.add_chart),
                          label: const Text('Monitorar Ação'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // Botão Cancelar
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(foregroundColor: primaryColor),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
