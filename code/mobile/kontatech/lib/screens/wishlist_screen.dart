import 'package:flutter/material.dart';
import 'package:kontatech/services/wishlist_service.dart';
import 'package:kontatech/screens/create_wishlist_item_screen.dart';

/// Tela de monitoramento de ações/ativos financeiros
/// Permite ao usuário definir preços-alvo e receber notificações
/// quando o preço da ação atingir o valor desejado
class WishlistScreen extends StatefulWidget {
  static const routeName = '/wishlist';
  final String groupId;
  final String? groupName;

  const WishlistScreen({
    super.key,
    required this.groupId,
    this.groupName,
  });

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  // Modifique a assinatura para aceitar um parâmetro opcional
  Future<void> _loadWishlist({bool showLoading = true}) async {
    // Só mostra o indicador de carregamento na primeira vez ou quando for manual
    if (showLoading) {
      setState(() => _isLoading = true);
    }

    final result = await WishlistService.listWishlistByGroup(widget.groupId);

    if (!mounted) return;

    setState(() {
      _items = result ?? [];
      _isLoading = false;
    });

    if (result == null && showLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao carregar ações monitoradas'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // === LÓGICA DE ATUALIZAÇÃO AUTOMÁTICA ===
    // Verifica se existe algum item na lista com preço zerado ou pendente
    final temItemPendente = _items.any((item) {
      final precoAtual = item['preco_atual'];
      // Verifica se é null ou se, convertido para double, é zero
      if (precoAtual == null) return true;
      final valor = double.tryParse(precoAtual.toString()) ?? 0.0;
      return valor <= 0;
    });

    // Se houver item pendente, agendamos uma nova busca daqui a 3 segundos
    // mas SEM mostrar o loading spinner (silent update)
    if (temItemPendente) {
      // print('Item pendente detectado. Atualizando em 3 segundos...'); // Debug
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _loadWishlist(showLoading: false);
        }
      });
    }
  }

  void _navigateToCreateItem() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateWishlistItemScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
        ),
      ),
    );

    // Se um novo item foi criado, recarrega a lista
    if (result == true) {
      _loadWishlist();
    }
  }

  void _showDeleteDialog(Map<String, dynamic> item) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final symbol = (item['symbol'] ?? '').toString().toUpperCase();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Parar de Monitorar'),
        content: Text(
          'Deseja parar de monitorar a ação "$symbol"?\n\nVocê não receberá mais notificações sobre essa ação.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              final success = await WishlistService.deleteWishlistItem(item['id']);
              
              if (success) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('$symbol removido do monitoramento'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadWishlist();
              } else {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Erro ao remover ação'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName != null 
            ? 'Ações - ${widget.groupName}' 
            : 'Monitoramento de Ações'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () => _loadWishlist(showLoading: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildWishlistCard(item);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateItem,
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.candlestick_chart_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma ação monitorada',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione ações para monitorar e receba notificações quando o preço atingir seu alvo!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToCreateItem,
              icon: const Icon(Icons.add_chart),
              label: const Text('Monitorar Ação'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlistCard(Map<String, dynamic> item) {
    final precoAlvo = item['preco_alvo'];
    final precoAtual = item['preco_atual'];
    final atingido = item['atingido'] == true;
    final expirado = item['expirado'] == true;
    final symbol = item['symbol'] ?? '';
    final titulo = item['titulo'];
    final provider = item['provider'] ?? 'FINNHUB';
    final dataLimiteStr = item['data_limite'];

    // Converte preços para double
    final precoAlvoDouble = precoAlvo is num 
        ? precoAlvo.toDouble() 
        : double.tryParse(precoAlvo?.toString() ?? '0') ?? 0.0;

    double? precoAtualDouble;
    if (precoAtual != null) {
      final val = double.tryParse(precoAtual.toString());
      // Se val for maior que 0, consideramos válido. Se for 0.0, consideramos pendente.
      if (val != null && val > 0) {
        precoAtualDouble = val;
      }
    }
    
    // Calcula a diferença percentual entre preço atual e alvo
    double? diferencaPercentual;
    if (precoAtualDouble != null && precoAlvoDouble > 0) {
      diferencaPercentual = ((precoAtualDouble - precoAlvoDouble) / precoAlvoDouble) * 100;
    }

    // Determina se está em queda (bom para compra) ou em alta
    final emQueda = precoAtualDouble != null && precoAtualDouble <= precoAlvoDouble;
    
    // Processa data limite
    DateTime? dataLimite;
    String? tempoRestante;
    bool prazoProximoVencer = false;
    
    if (dataLimiteStr != null && !atingido && !expirado) {
      try {
        dataLimite = DateTime.parse(dataLimiteStr);
        final agora = DateTime.now();
        final diferenca = dataLimite.difference(agora);
        
        if (diferenca.isNegative) {
          tempoRestante = 'Expirado';
        } else if (diferenca.inDays > 0) {
          tempoRestante = '${diferenca.inDays}d ${diferenca.inHours % 24}h restantes';
          prazoProximoVencer = diferenca.inDays < 1;
        } else if (diferenca.inHours > 0) {
          tempoRestante = '${diferenca.inHours}h ${diferenca.inMinutes % 60}min restantes';
          prazoProximoVencer = diferenca.inHours < 2;
        } else {
          tempoRestante = '${diferenca.inMinutes}min restantes';
          prazoProximoVencer = true;
        }
      } catch (_) {}
    }

    // Define cor do card baseado no status
    Color? borderColor;
    if (expirado) {
      borderColor = Colors.red;
    } else if (atingido) {
      borderColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderColor != null 
            ? BorderSide(color: borderColor, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Symbol/Título e Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone de ação
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: expirado
                        ? Colors.red.withOpacity(0.1)
                        : atingido 
                            ? Colors.green.withOpacity(0.1)
                            : emQueda
                                ? Colors.teal.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    expirado
                        ? Icons.timer_off
                        : atingido 
                            ? Icons.notifications_active 
                            : emQueda
                                ? Icons.trending_down
                                : Icons.trending_up,
                    color: expirado
                        ? Colors.red
                        : atingido 
                            ? Colors.green 
                            : emQueda
                                ? Colors.teal
                                : Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Symbol e Título
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        symbol.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (titulo != null && titulo.isNotEmpty)
                        Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        'Fonte: $provider',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge de status
                if (expirado)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_off, size: 14, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          'Expirado',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (atingido)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_active, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'Comprar!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (tempoRestante != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: prazoProximoVencer 
                          ? Colors.orange.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined, 
                          size: 14, 
                          color: prazoProximoVencer ? Colors.orange : Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tempoRestante,
                          style: TextStyle(
                            fontSize: 11,
                            color: prazoProximoVencer ? Colors.orange[800] : Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Preços
            Row(
              children: [
                // Preço Alvo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.flag_outlined, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Preço Alvo',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$ ${precoAlvoDouble.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                // Preço Atual
                if (precoAtualDouble != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.show_chart, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Preço Atual',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$ ${precoAtualDouble.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: emQueda ? Colors.green : Colors.orange,
                              ),
                            ),
                            if (diferencaPercentual != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: diferencaPercentual <= 0 
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${diferencaPercentual >= 0 ? '+' : ''}${diferencaPercentual.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: diferencaPercentual <= 0 
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            // Indicador de status
            if (expirado) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_off, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Prazo expirado sem atingir o preço-alvo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (precoAtualDouble != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: emQueda 
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      emQueda ? Icons.thumb_up : Icons.hourglass_empty,
                      size: 16,
                      color: emQueda ? Colors.green[700] : Colors.orange[700],
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        emQueda 
                            ? 'Preço atingiu o alvo! Hora de comprar!'
                            : 'Aguardando preço cair para o alvo...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: emQueda ? Colors.green[700] : Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sync, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Aguardando atualização de preço...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Botão de excluir
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showDeleteDialog(item),
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                label: const Text('Remover', style: TextStyle(color: Colors.red)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
