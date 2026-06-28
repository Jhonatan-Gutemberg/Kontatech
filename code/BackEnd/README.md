# KontaTech - Backend

Este é o backend do KontaTech desenvolvido em Python com FastAPI e PostgreSQL.

## 1) Clonar e entrar na pasta
```
git clone <URL_DO_REPO>
cd BackEnd
```

## 2) Criar e ativar ambiente virtual
- Windows
```
python -m venv venv
venv\Scripts\activate
```
- Linux/Mac
```
python3 -m venv venv
source venv/bin/activate
```

IMPORTANTE: Sempre que for rodar o projeto, o ambiente virtual deve estar ATIVADO. Verifique se aparece `(venv)` no início do prompt; caso não, reative com os comandos acima antes de instalar dependências ou iniciar o servidor.

## 3) Instalar dependências
```
pip install -r requirements.txt
```

## 4) Banco de dados (pgAdmin, via clique)
- Crie o banco: `kontatech_db` (UTF-8)
- Crie/defina um usuário com senha e acesso ao banco (ex.: `admin / admin123`)
- Porta padrão: `5432`

## 5) Ajustar `.env` (já existe no projeto)
- Abra o arquivo `.env` na pasta `BackEnd` e edite apenas a linha `DATABASE_URL`.
- Substitua `<usuario>:<senha>` pelo usuário e senha que você criou no pgAdmin.
- Exemplo:
```
DATABASE_URL=postgresql+pg8000://admin:admin123@localhost:5432/kontatech_db
SECRET_KEY=changeme
DEBUG=True
```

## 6) Rodar o servidor
```
python run_server.py
```

## 7) Swagger e Health
- Swagger: http://127.0.0.1:8000/docs
- Health: http://127.0.0.1:8000/health

## Notas
- As tabelas são criadas automaticamente no startup.
- Se não conectar: verifique usuário/senha/porta no `.env` e se o banco existe no pgAdmin.

## Wishlist de Investimentos (Ações e Cripto) via Finnhub

A funcionalidade de wishlist agora monitora ativos financeiros (ações e criptomoedas) usando a API da Finnhub. A arquitetura permanece a mesma (tabela, rotas, validações, WebSocket e RabbitMQ), apenas a fonte de preço e o modelo foram ajustados para o contexto de investimentos.

### Como funciona com Finnhub
- Fonte de dados: `Finnhub` (ações, cripto e forex) com plano gratuito.
- Modelo: `WishlistItem` usa `symbol` (ex.: `AAPL`, `TSLA`, `PETR4.SA`, `BINANCE:BTCUSDT`) e `provider="FINNHUB"`.
- Worker periódico:
  - Consulta `GET https://finnhub.io/api/v1/quote?symbol={SYMBOL}&token={FINNHUB_TOKEN}`.
  - Usa o campo `c` (preço atual).
  - Quando `c <= preco_alvo`, atualiza `preco_atual`, marca `atingido=true` e publica notificação (RabbitMQ → WebSocket).
- Arquitetura restante permanece igual: autenticação, rotas, validações, notificações em tempo real.

- Expiração de prazo (`data_limite`/`expirado`): itens podem ter um prazo opcional. O worker marca `expirado=true` quando o prazo passa e publica uma notificação de expiração.

### Variáveis de ambiente
- `FINNHUB_TOKEN`: obrigatório (chave de API)
- `WISHLIST_CHECK_INTERVAL`: opcional, em segundos (padrão `60`)

### Guia rápido para o Frontend
- Autenticação
  - Envie `Authorization: Bearer <token>` em todas as chamadas.

- Criar item de wishlist
  - `POST /wishlist/`
  - Body: `{ "grupo_id": "<UUID>", "symbol": "AAPL", "preco_alvo": 170.00, "titulo": "Apple Inc.", "data_limite": "2024-12-31T23:59:59Z" }`
  - Retorno: `{ "id": "<UUID>", "grupo_id": "<UUID>", "symbol": "AAPL", "provider": "FINNHUB", "titulo": "Apple Inc.", "preco_alvo": 170.00, "preco_atual": null, "atingido": false, "expirado": false, "data_limite": "2024-12-31T23:59:59Z", "data_criacao": "<ISO>" }`

- Listar itens da wishlist (por grupo)
  - `GET /wishlist/grupo/{grupo_id}`
  - Retorno: lista com `preco_atual` preenchido após a primeira execução do worker.

- Notificações em tempo real
  - Canal WebSocket já existente no app recebe payload quando alvo é atingido:
  - `{ "grupo_id": "<UUID>", "symbol": "AAPL", "titulo": "Apple Inc.", "preco_alvo": "170.00", "preco_atual": "169.80", "provider": "FINNHUB", "mensagem": "Preço-alvo atingido para wishlist de investimentos" }`
  - Expiração de prazo: `{ "grupo_id": "<UUID>", "symbol": "BINANCE:ETHUSDT", "expirado": true, "data_limite": "2024-09-01T12:00:00Z", "mensagem": "Prazo expirado para item de wishlist" }`

- Dica de demonstração
  - Defina `WISHLIST_CHECK_INTERVAL=10–15` e escolha `preco_alvo` próximo ao `c` atual para ver notificações rapidamente.

- Opcional (nome do ativo)
  - `GET https://finnhub.io/api/v1/stock/profile2?symbol={SYMBOL}&token={FINNHUB_TOKEN}` e use `name` como título.
