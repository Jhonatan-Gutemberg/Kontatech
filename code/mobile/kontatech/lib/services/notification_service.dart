import 'dart:async';
import 'dart:convert';
import 'package:kontatech/api/websocket_client.dart';
import 'package:kontatech/config/api_config.dart';
import 'package:kontatech/utils/secure_storage.dart';
import 'package:kontatech/services/expense_service.dart';

/// Modelo de notificação
class AppNotification {
  final String id;
  final String title;
  final String message;
  final String? type;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    this.type,
    required this.timestamp,
    this.isRead = false,
  });

factory AppNotification.fromJson(Map<String, dynamic> json) {
    // Verifica se o JSON já está normalizado ou se é o formato bruto do backend
    bool isNormalized = json.containsKey('id') && !json.containsKey('routing_key');
    
    if (isNormalized) {
      // JSON já normalizado - usado internamente
      return AppNotification(
        id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'] ?? 'Notificação',
        message: json['message'] ?? '',
        type: json['type'],
        timestamp: json['timestamp'] != null 
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
        isRead: json['is_read'] ?? false,
      );
    } else {
      // Formato bruto do backend (legado) - não deveria ser usado mais
      final data = json['data'] is Map ? json['data'] : <String, dynamic>{};
      final routingKey = json['routing_key']?.toString() ?? '';

      String title = json['title'] ?? 'Nova Notificação';
      String message = json['message'] ?? json['body'] ?? '';
      String type = json['type'] ?? 'generic';
      
      if (routingKey.contains('despesa')) {
        type = 'expense';
        title = 'Nova Despesa Adicionada';
        final nomeDespesa = data['titulo'] ?? 'Despesa sem nome';
        final valor = data['valor_total']?.toString() ?? '0.00';
        message = "R\$ $valor - $nomeDespesa";
      }

      return AppNotification(
        id: data['despesa_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        message: message,
        type: type,
        timestamp: DateTime.now(),
        isRead: false,
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'type': type,
    'timestamp': timestamp.toIso8601String(),
    'is_read': isRead,
  };
}

/// Serviço singleton para gerenciar notificações e conexão WebSocket
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  WebSocketClient? _wsClient;
  bool _isConnected = false;
  
  // Lista de notificações
  final List<AppNotification> _notifications = [];
  
  // Stream controller para notificar mudanças
  final _notificationsController = StreamController<List<AppNotification>>.broadcast();
  Stream<List<AppNotification>> get notificationsStream => _notificationsController.stream;
  
  // Stream controller para novas notificações (para mostrar snackbar/toast)
  final _newNotificationController = StreamController<AppNotification>.broadcast();
  Stream<AppNotification> get newNotificationStream => _newNotificationController.stream;

  // Getter para verificar conexão
  bool get isConnected => _isConnected;
  
  // Getter para notificações
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  
  // Contador de não lidas
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Conecta ao WebSocket de notificações
  Future<bool> connect() async {
    if (_isConnected) return true;

    final token = await SecureStorage.getToken();
    if (token == null) {
      print('NotificationService: Token não encontrado');
      return false;
    }

    try {
      final wsUrl = wsNotificationsUrl(token);
      _wsClient = WebSocketClient(wsUrl: wsUrl);
      
      await _wsClient!.connect(
        _onMessage,
        onDone: _onDisconnected,
        onError: _onError,
      );
      
      _isConnected = true;
      print('NotificationService: Conectado ao WebSocket');
      return true;
    } catch (e) {
      print('NotificationService: Erro ao conectar - $e');
      _isConnected = false;
      return false;
    }
  }

  /// Desconecta do WebSocket
  Future<void> disconnect() async {
    try {
      await _wsClient?.disconnect();
    } catch (_) {}
    _wsClient = null;
    _isConnected = false;
    print('NotificationService: Desconectado');
  }

  /// Handler de mensagens recebidas
  void _onMessage(dynamic message) async {
    try {
      print('NotificationService: Mensagem recebida - $message');
      
      Map<String, dynamic> data;
      if (message is String) {
        data = jsonDecode(message);
      } else if (message is Map) {
        data = Map<String, dynamic>.from(message);
      } else {
        print('NotificationService: Formato de mensagem desconhecido');
        return;
      }
      // Normaliza formato proveniente do backend { routing_key, data }
      AppNotification notification;
      if (data.containsKey('routing_key') && data.containsKey('data')) {
        final String routing = data['routing_key']?.toString() ?? '';
        final Map<String, dynamic> payload = Map<String, dynamic>.from(data['data'] ?? {});

        // Derivar título pelo tipo
        String derivedTitle = payload['title']?.toString() ?? 'Notificação';
        if (derivedTitle == 'Notificação') {
          if (routing.startsWith('notificacao.despesa.criada')) {
            derivedTitle = 'Despesa criada';
          } else if (routing.startsWith('notificacao.wishlist.preco_atingido')) {
            derivedTitle = 'Preço-alvo atingido';
          } else if (routing.startsWith('notificacao.wishlist.prazo_expirado')) {
            derivedTitle = 'Prazo expirado';
          }
        }

        // Derivar mensagem: usa 'mensagem' se existir; senão compõe
        String derivedMessage = (payload['message'] ?? payload['mensagem'] ?? '').toString();
        if (derivedMessage.isEmpty) {
          if (routing.startsWith('notificacao.despesa.criada')) {
            final titulo = payload['titulo']?.toString() ?? 'Despesa';
            final descricao = payload['descricao']?.toString();
            
            // Buscar o valor que o usuário atual deve (não o valor total)
            String valorStr = '';
            try {
              final despesaId = payload['despesa_id']?.toString();
              final userId = await SecureStorage.getUserId();
              
              if (despesaId != null && userId != null) {
                // Busca os dados completos da despesa
                final expenseData = await ExpenseService.getExpenseById(despesaId);
                
                if (expenseData != null && expenseData['divisao'] != null) {
                  // Encontra o valor devido pelo usuário atual
                  final divisoes = expenseData['divisao'] as List<dynamic>;
                  final divisaoUsuario = divisoes.firstWhere(
                    (d) => d['usuario_id'] == userId,
                    orElse: () => null,
                  );
                  
                  if (divisaoUsuario != null) {
                    final valorDevido = divisaoUsuario['valor_devido'];
                    if (valorDevido is num) {
                      valorStr = 'Você deve R\$ ${valorDevido.toStringAsFixed(2)}';
                    }
                  }
                }
              }
              
              // Se não conseguiu buscar o valor específico, usa o valor total como fallback
              if (valorStr.isEmpty) {
                final valor = payload['valor_total'];
                valorStr = (valor is num)
                    ? 'Total R\$ ${valor.toStringAsFixed(2)}'
                    : (valor?.toString() ?? '');
              }
            } catch (e) {
              print('Erro ao buscar valor devido: $e');
              // Fallback para valor total em caso de erro
              final valor = payload['valor_total'];
              valorStr = (valor is num)
                  ? 'Total R\$ ${valor.toStringAsFixed(2)}'
                  : (valor?.toString() ?? '');
            }
            
            derivedMessage = '"$titulo" criada. $valorStr' +
                (descricao != null && descricao.isNotEmpty ? ' • $descricao' : '');
          } else if (routing.startsWith('notificacao.wishlist.preco_atingido')) {
            derivedMessage = 'Um item da sua wishlist atingiu o preço alvo.';
          } else if (routing.startsWith('notificacao.wishlist.prazo_expirado')) {
            derivedMessage = 'Um item da sua wishlist expirou o prazo.';
          }
        }

        // Extrai o ID correto baseado no tipo de notificação
        String notificationId;
        if (routing.contains('despesa')) {
          notificationId = payload['despesa_id']?.toString() ?? payload['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
        } else if (routing.contains('wishlist')) {
          notificationId = payload['wishlist_item_id']?.toString() ?? payload['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
        } else {
          notificationId = payload['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
        }

        final normalized = {
          'id': notificationId,
          'title': derivedTitle,
          'message': derivedMessage,
          'type': routing,
          'timestamp': DateTime.now().toIso8601String(),
          'is_read': false,
        };
        notification = AppNotification.fromJson(normalized);
      } else {
        // Formato já compatível
        notification = AppNotification.fromJson(data);
      }
      
      // Adiciona no início da lista
      _notifications.insert(0, notification);
      
      // Notifica listeners
      _notificationsController.add(List.from(_notifications));
      _newNotificationController.add(notification);
      
    } catch (e) {
      print('NotificationService: Erro ao processar mensagem - $e');
    }
  }

  /// Handler de desconexão
  void _onDisconnected() {
    _isConnected = false;
    print('NotificationService: Conexão encerrada');
    
    // Tenta reconectar após 5 segundos
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isConnected) {
        print('NotificationService: Tentando reconectar...');
        connect();
      }
    });
  }

  /// Handler de erro
  void _onError(dynamic error) {
    print('NotificationService: Erro - $error');
    _isConnected = false;
  }

  /// Marca uma notificação como lida
  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index].isRead = true;
      _notificationsController.add(List.from(_notifications));
    }
  }

  /// Marca todas as notificações como lidas
  void markAllAsRead() {
    for (var notification in _notifications) {
      notification.isRead = true;
    }
    _notificationsController.add(List.from(_notifications));
  }

  /// Remove uma notificação
  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _notificationsController.add(List.from(_notifications));
  }

  /// Limpa todas as notificações
  void clearAll() {
    _notifications.clear();
    _notificationsController.add(List.from(_notifications));
  }

  /// Adiciona uma notificação local (para testes ou notificações internas)
  void addLocalNotification({
    required String title,
    required String message,
    String? type,
  }) {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
    );
    
    _notifications.insert(0, notification);
    _notificationsController.add(List.from(_notifications));
    _newNotificationController.add(notification);
  }

  /// Dispose dos resources
  void dispose() {
    disconnect();
    _notificationsController.close();
    _newNotificationController.close();
  }
}

