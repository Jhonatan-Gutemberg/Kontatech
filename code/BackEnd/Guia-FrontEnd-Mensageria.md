# Guia de Mensageria para Front-end

Este guia explica de forma objetiva como o front-end (web ou mobile) consome as notificações do sistema via WebSocket, incluindo pré-requisitos, conexão, formato das mensagens, tratamento e testes.

## Objetivo
- Receber notificações em tempo real (despesas e wishlist de investimentos: ações e criptomoedas via Finnhub) direcionadas ao usuário autenticado.
- Integrar com o backend usando um WebSocket autenticado com JWT.

## Visão Geral
- O backend consome eventos do RabbitMQ e entrega ao front-end via WebSocket.
- A entrega agora é direcionada por usuário (não é mais broadcast global).
- URL do WebSocket: `ws://<HOST>:<PORT>/ws/notifications?token=<JWT>`.
- Cada mensagem é um JSON com `routing_key` e `data`.

## Pré-requisitos
- Ter um `access_token` (JWT) obtido em `POST /auth/login`.
- Saber o `HOST` e `PORT` do backend.
- Em produção, preferir `wss://` e não logar o token.

## Conexão WebSocket
- Construa a URL com o token JWT na query:
  - `ws://<HOST>:<PORT>/ws/notifications?token=<JWT>`
- Se o token estiver ausente/ inválido, o servidor encerra a conexão com código `4401`.
- Suporta múltiplas sessões por usuário (ex.: app e web), todas recebem as mensagens do mesmo `user_id`.

## Formato das Mensagens
- Sempre um JSON com:
  - `routing_key`: tópico da notificação.
  - `data`: payload com os campos do evento.

### Exemplo — Despesa criada
```json
{
  "routing_key": "notificacao.despesa.criada",
  "data": {
    "id": "desp-123",
    "descricao": "Almoço",
    "valor": 45.90,
    "destinatarios": [1, 2]
  }
}
```
- Entrega: apenas aos usuários listados em `data.destinatarios`.
- Front-end não precisa filtrar por `user_id` (já vem direcionado).

### Exemplo — Wishlist de investimentos: preço alvo atingido
```json
{
  "routing_key": "notificacao.wishlist.preco_atingido.42",
  "data": {
    "grupo_id": 42,
    "item_id": "wl-987",
    "simbolo": "AAPL",
    "provedor": "FINNHUB",
    "preco_alvo": 199.90,
    "preco_atual": 199.90,
    "moeda": "USD",
    "expirado": false,
    "data_limite": "2024-12-31T23:59:59Z"
  }
}
```
- Entrega: para todos os membros do grupo `data.grupo_id`.
- Exibição: opcionalmente filtre por grupo ativo na UI (`data.grupo_id == currentGroupId`).

## Como Exibir no App
- Despesas: exiba diretamente (já direcionado ao usuário logado).
- Wishlist de investimentos: exiba quando o grupo da tela atual corresponder a `data.grupo_id` ou apresente um aviso global com indicação do grupo. Mostre claramente `simbolo`, `moeda`, `preco_alvo`, `preco_atual` e, quando aplicável, indique expiração pelo campo `expirado`.

## Snippet Flutter (conexão e consumo)
Exemplo simples usando `web_socket_channel`:

```dart
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class NotificacoesService {
  WebSocketChannel? _channel;
  final String host;
  final int port;
  final String jwt;

  NotificacoesService({required this.host, required this.port, required this.jwt});

  Uri _buildUri() => Uri.parse('ws://$host:$port/ws/notifications?token=$jwt');

  void conectar({void Function(Map<String, dynamic>)? onMessage, void Function(Object)? onError, void Function()? onDone}) {
    _channel = WebSocketChannel.connect(_buildUri());

    _channel!.stream.listen((event) {
      try {
        final Map<String, dynamic> msg = json.decode(event);
        // msg: { "routing_key": "...", "data": { ... } }
        onMessage?.call(msg);
      } catch (e) {
        onError?.call(e);
      }
    }, onError: (err) {
      onError?.call(err);
    }, onDone: () {
      onDone?.call();
    });
  }

  void desconectar() {
    _channel?.sink.close();
    _channel = null;
  }
}
```

Uso:
```dart
final svc = NotificacoesService(host: 'localhost', port: 8000, jwt: accessToken);
svc.conectar(onMessage: (msg) {
  final key = msg['routing_key'] as String?;
  final data = msg['data'] as Map<String, dynamic>?;
  if (key == null || data == null) return;

  if (key == 'notificacao.despesa.criada') {
    // Exiba a despesa
  } else if (key.startsWith('notificacao.wishlist.preco_atingido.')) {
    // Exiba alerta de investimento se grupo atual corresponder a data['grupo_id']
  }
});
```

## Reconexão e Erros
- Se a conexão cair, tente reconectar com backoff (ex.: 2s, 5s, 10s).
- Se receber fechamento com `4401`, renove o token via login e reconecte.
- Em produção use `wss://` e evite imprimir o token em logs.

## Testes Rápidos de Fim-a-Fim
1. Login e token:
   - `POST /auth/login` → obtenha `access_token` (JWT).
2. Conecte ao WebSocket:
   - `ws://<HOST>:<PORT>/ws/notifications?token=<JWT>` e logue mensagens.
3. Gatilhos de despesa:
   - `POST /despesas/` com `destinatarios: [<user_id_logado>]`.
   - O usuário logado deve receber `notificacao.despesa.criada`.
4. Gatilhos de wishlist de investimentos:
   - `POST /wishlist/` com `simbolo` (ex.: `AAPL`, `PETR4.SA`, `BINANCE:BTCUSDT`) para um `grupo_id` do qual o usuário é membro.
   - Aguarde verificação periódica (env `WISHLIST_CHECK_INTERVAL`, padrão `60s`). O backend consulta preços via Finnhub.
   - Receba `notificacao.wishlist.preco_atingido.<grupo_id>` quando o preço atual atingir o preço-alvo.

## Observações
- Mensagens são em tempo real e não são persistidas para offline.
- Várias sessões do mesmo usuário recebem as mesmas notificações.
- Futuras evoluções podem mover o token para subprotocol/cookie; para a demo, `?token=` é suficiente.

---

Dúvidas ou problemas na integração? Verifique a documentação de autenticação e o `Swagger-Guia-Testes.md` para exemplos de uso com token.
