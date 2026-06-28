import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kontatech/screens/dashboard_screen.dart';
import 'package:kontatech/screens/groups_list_screen.dart';
import 'package:kontatech/screens/home_screen.dart';
import 'package:kontatech/screens/profile_screen.dart';
import 'package:kontatech/screens/notifications_screen.dart';
import 'package:kontatech/screens/loginScreen.dart';
import 'package:kontatech/screens/expense_detail_screen.dart';
import 'package:kontatech/services/notification_service.dart';
import 'package:kontatech/services/user_service.dart';
import 'package:kontatech/utils/secure_storage.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String _appBarTitle = 'Seja bem vindo ao KontaTech!';
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<List<AppNotification>>? _notificationSubscription;
  StreamSubscription<AppNotification>? _newNotificationSubscription;
  int _unreadCount = 0;
  String? _userName;
  String? _userEmail;

  // Lista de páginas que o Drawer pode exibir
  static const List<Widget> _pages = <Widget>[
    const DashboardScreen(),
    const HomePageContent(),
    const GroupsListScreen(embedded: true),
    const ProfileScreen(embedded: true),
    const NotificationsScreen(embedded: true),
  ];

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await UserService.getCurrentUser();
      if (!mounted) return;
      if (user != null) {
        setState(() {
          _userName = (user['nome'] ?? '').toString().trim().isNotEmpty
              ? user['nome'].toString()
              : null;
          _userEmail = (user['email'] ?? '').toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _initNotifications() async {
    // Conecta ao WebSocket de notificações
    await _notificationService.connect();
    
    // Atualiza contador de não lidas
    setState(() {
      _unreadCount = _notificationService.unreadCount;
    });

    // Subscribe para atualizações
    _notificationSubscription = _notificationService.notificationsStream.listen((notifications) {
      if (mounted) {
        setState(() {
          _unreadCount = _notificationService.unreadCount;
        });
      }
    });

    // Subscribe para novas notificações (mostrar snackbar)
    _newNotificationSubscription = _notificationService.newNotificationStream.listen((notification) {
      if (mounted && _selectedIndex != 4) {
        // Limpa qualquer snackbar anterior antes de mostrar a nova
        ScaffoldMessenger.of(context).clearSnackBars();
        
        final messenger = ScaffoldMessenger.of(context);

        // Mostra snackbar apenas se não estiver na tela de notificações
        final controller = messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        notification.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Ver',
              textColor: Colors.white,
              onPressed: () {
                // Fecha a notificação imediatamente ao clicar
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _handleNotificationTap(notification);
              },
            ),
            backgroundColor: Theme.of(context).primaryColor,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            dismissDirection: DismissDirection.down,
          ),
        );

        // Garante que o snackbar desapareça após o tempo configurado
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            controller.close();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _newNotificationSubscription?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      switch (index) {
        case 0:
          _appBarTitle = 'Home';
          break;
        case 1:
          _appBarTitle = 'Despesas por grupo';
          break;
        case 2:
          _appBarTitle = 'Meus Grupos';
          break;
        case 3:
          _appBarTitle = 'Meu Perfil';
          break;
        case 4:
          _appBarTitle = 'Notificações';
          break;
      }
    });
    Navigator.pop(context);
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
    } else {
      // Para outros tipos de notificação, vai para a tela de notificações
      _onItemTapped(4);
    }
  }

  Future<void> _logout() async {
    await _notificationService.disconnect();
    await SecureStorage.deleteToken();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: [
          // Botão de notificações com badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  setState(() {
                    _selectedIndex = 4;
                    _appBarTitle = 'Notificações';
                  });
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    child: Text(
                      (_userName != null && _userName!.isNotEmpty)
                          ? _userName!.substring(0, 1).toUpperCase()
                          : 'K',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _userName ?? 'KontaTech',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _userEmail ?? 'Gerencie suas despesas',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('Home'),
              selected: _selectedIndex == 0,
              selectedColor: primaryColor,
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Despesas por grupo'),
              selected: _selectedIndex == 1,
              selectedColor: primaryColor,
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Grupos'),
              selected: _selectedIndex == 2,
              selectedColor: primaryColor,
              onTap: () => _onItemTapped(2),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Meu Perfil'),
              selected: _selectedIndex == 3,
              selectedColor: primaryColor,
              onTap: () => _onItemTapped(3),
            ),
            ListTile(
              leading: Stack(
                children: [
                  const Icon(Icons.notifications),
                  if (_unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          _unreadCount > 9 ? '9+' : '$_unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              title: const Text('Notificações'),
              selected: _selectedIndex == 4,
              selectedColor: primaryColor,
              onTap: () => _onItemTapped(4),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }
}
