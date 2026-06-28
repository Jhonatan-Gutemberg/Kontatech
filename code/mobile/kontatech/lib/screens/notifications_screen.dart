import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kontatech/services/notification_service.dart';
import 'package:kontatech/screens/expense_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  static const routeName = '/notifications';
  final bool embedded;
  const NotificationsScreen({super.key, this.embedded = false});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<List<AppNotification>>? _subscription;
  List<AppNotification> _notifications = [];
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    // Carrega notificações existentes
    _notifications = _notificationService.notifications;
    
    // Subscribe para atualizações
    _subscription = _notificationService.notificationsStream.listen((notifications) {
      if (mounted) {
        setState(() {
          _notifications = notifications;
        });
      }
    });

    // Conecta ao WebSocket se não estiver conectado
    if (!_notificationService.isConnected) {
      setState(() => _isConnecting = true);
      await _notificationService.connect();
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _markAllAsRead() {
    _notificationService.markAllAsRead();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todas as notificações marcadas como lidas'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Notificações'),
        content: const Text('Deseja remover todas as notificações?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _notificationService.clearAll();
            },
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }

  void _reconnect() async {
    setState(() => _isConnecting = true);
    await _notificationService.disconnect();
    await _notificationService.connect();
    if (mounted) {
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_notificationService.isConnected 
              ? 'Reconectado com sucesso!' 
              : 'Falha ao reconectar'),
          backgroundColor: _notificationService.isConnected 
              ? Colors.green 
              : Colors.red,
        ),
      );
    }
  }

  void _handleNotificationTap(AppNotification notification) {
    // Verifica se é uma notificação de despesa
    if (notification.type != null && notification.type!.contains('despesa')) {
      // Navega para a tela de detalhes da despesa
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExpenseDetailScreen(
            expenseId: notification.id,
            initialTitle: notification.title,
          ),
        ),
      );
    }
    // Para outros tipos de notificação, apenas marca como lida (já feito no onTap)
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notificationService.unreadCount;

    final headerActions = _notifications.isNotEmpty
        ? [
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: _markAllAsRead,
              tooltip: 'Marcar todas como lidas',
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAll,
              tooltip: 'Limpar todas',
            ),
          ]
        : <Widget>[];

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Row(
                children: [
                  const Text('Notificações'),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: headerActions,
            ),
      body: Column(
        children: [
          if (widget.embedded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notificações',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ...headerActions,
                ],
              ),
            ),
          // Status da conexão
          _buildConnectionStatus(),
          
          // Lista de notificações
          Expanded(
            child: _isConnecting
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Conectando ao servidor...'),
                      ],
                    ),
                  )
                : _notifications.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async {
                          _reconnect();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            return _buildNotificationCard(_notifications[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final isConnected = _notificationService.isConnected;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isConnected ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.cloud_done : Icons.cloud_off,
            size: 18,
            color: isConnected ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isConnected 
                  ? 'Conectado - recebendo notificações em tempo real'
                  : 'Desconectado - toque para reconectar',
              style: TextStyle(
                fontSize: 12,
                color: isConnected ? Colors.green[700] : Colors.orange[700],
              ),
            ),
          ),
          if (!isConnected && !_isConnecting)
            TextButton(
              onPressed: _reconnect,
              child: const Text('Reconectar'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma notificação',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Suas notificações aparecerão aqui',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          if (!_notificationService.isConnected)
            ElevatedButton.icon(
              onPressed: _reconnect,
              icon: const Icon(Icons.refresh),
              label: const Text('Conectar'),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    final isUnread = !notification.isRead;
    
    // Define ícone e cor baseado no tipo
    IconData iconData;
    Color iconColor;
    switch (notification.type) {
      case 'expense':
        iconData = Icons.receipt_long;
        iconColor = Colors.green;
        break;
      case 'group':
        iconData = Icons.group;
        iconColor = Colors.blue;
        break;
      case 'wishlist':
        iconData = Icons.card_giftcard;
        iconColor = Colors.purple;
        break;
      case 'alert':
        iconData = Icons.warning;
        iconColor = Colors.orange;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        _notificationService.removeNotification(notification.id);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        elevation: isUnread ? 3 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isUnread 
              ? BorderSide(color: Theme.of(context).primaryColor, width: 1)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () {
            _notificationService.markAsRead(notification.id);
            _handleNotificationTap(notification);
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                // Conteúdo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTimestamp(notification.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Agora';
    } else if (diff.inMinutes < 60) {
      return 'Há ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Há ${diff.inHours}h';
    } else if (diff.inDays == 1) {
      return 'Ontem';
    } else if (diff.inDays < 7) {
      return 'Há ${diff.inDays} dias';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
