import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketClient {
  final String wsUrl;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;

  WebSocketClient({required this.wsUrl});

  /// Conecta ao websocket. Fecha conexão anterior se existir.
  Future<void> connect(
    void Function(dynamic message) onMessage, {
    void Function()? onDone,
    void Function(dynamic)? onError,
  }) async {
    await disconnect();
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _sub = _channel!.stream.listen(
        onMessage,
        onDone: onDone,
        onError: (err) {
          if (onError != null) onError(err);
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (onError != null) onError(e);
      else rethrow;
    }
  }

  /// Envia mensagem. Lança se não estiver conectado.
  Future<void> send(dynamic message) async {
    if (_channel == null) throw Exception('WebSocket not connected');
    _channel!.sink.add(message);
  }

  /// Desconecta e limpa recursos.
  Future<void> disconnect() async {
    try {
      await _sub?.cancel();
    } catch (_) {}
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _sub = null;
    _channel = null;
  }
}