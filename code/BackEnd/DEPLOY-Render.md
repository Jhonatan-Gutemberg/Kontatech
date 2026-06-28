# Deploy no Render (Back-end, Banco e Mensageria)

Guia direto e completo para publicar o back-end (FastAPI), banco de dados (PostgreSQL) e mensageria (RabbitMQ) no Render.

## Visão Geral
- Back-end: Web Service Python servindo HTTP + WebSocket (`/ws/notifications`).
- Banco: PostgreSQL gerenciado pelo Render.
- Mensageria: recomendado CloudAMQP; opcional RabbitMQ como Private Service no Render.
- Front-end conecta via `wss://<DOMÍNIO>/ws/notifications?token=<JWT>`.

## Pré-requisitos
- Repositório no GitHub com o projeto.
- Arquivo `requirements.txt` atualizado em `code/BackEnd/`.
- Alembic configurado (há `alembic.ini` e diretório `alembic/`).
- Variáveis de ambiente definidas no `README.md` do Back-end (consulte e prepare valores).

## Back-end como Web Service
1. Criar Web Service no Render:
   - Service → New → Web Service → Conectar seu repositório.
   - Root Directory: `code/BackEnd` (monorepo).
   - Runtime: `Python`.
2. Build Command:
   - `pip install -r requirements.txt`
3. Start Command:
   - `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
4. Environment Variables (no mínimo):
   - `SECRET_KEY`: segredo para JWT.
   - `DATABASE_URL`: URL do Postgres (use a interna do Render, ver seção Banco).
   - `RABBITMQ_URL`: URL da mensageria (CloudAMQP ou Private Service, ver seção Mensageria).
   - `WISHLIST_CHECK_INTERVAL`: em segundos (ex.: `60`).
   - `FINNHUB_TOKEN`: obrigatório para wishlist de investimentos (ações/cripto via Finnhub).
   - Opcional/recomendado: `API_BASE_URL` (defina para `https://<DOMÍNIO>`), `ALGORITHM` (padrão `HS256`), `ACCESS_TOKEN_EXPIRE_MINUTES` (ex.: `60`).
5. Post-Deploy Command (opcional, recomendado):
   - `alembic upgrade head`
   - Garante que o schema do banco está atualizado após cada deploy.

## Banco de Dados (PostgreSQL do Render)
1. Criar PostgreSQL:
   - Databases → New PostgreSQL → escolha região (mesma do Web Service).
2. Obter Connection String:
   - Use a `Internal Connection String` para reduzir latência e custo.
   - Ex.: `postgres://kontatech_db_user:UQJt228vM6tuYft9cexcQLAfRAZwAzZW@dpg-d4irr50gjchc73etbkcg-a:5432/kontatech_db`.
3. Configurar no Back-end:
   - No Web Service, adicione `DATABASE_URL` com a Internal Connection String.
4. Migrar schema:
   - Se usou Post-Deploy: já estará migrado.
   - Senão, rode manualmente (Render Jobs ou temporariamente no Start) `alembic upgrade head`.

## Mensageria (RabbitMQ)
### Opção A — CloudAMQP (mais simples)
1. Criar instância gratuita no CloudAMQP.
2. Pegar `AMQP_URL` (amqps):
   - Ex.: `amqps://<user>:<pass>@<host>/<vhost>` (TLS).
3. Configurar no Back-end:
   - No Web Service, adicione `RABBITMQ_URL` com o valor do CloudAMQP.
4. Pronto: o consumidor do back-end conectará e criará exchange/queues conforme o código.

### Opção B — RabbitMQ como Private Service no Render
1. Criar Private Service (Docker):
   - Image: `rabbitmq:3-management`.
   - Ports: `5672` (AMQP), `15672` (Management, privado por padrão).
   - Persistent Disk: attach volume (ex.: 1–5 GB) em `/var/lib/rabbitmq`.
2. Environment Variables do serviço RabbitMQ:
   - `RABBITMQ_DEFAULT_USER`: ex.: `kontatech`.
   - `RABBITMQ_DEFAULT_PASS`: senha forte.
3. Networking interna:
   - O back-end acessa via hostname interno do serviço (ex.: `rabbitmq`) na mesma região.
   - `RABBITMQ_URL`: `amqp://kontatech:<pass>@rabbitmq:5672/`.
4. Management UI (15672):
   - Se precisar acesso, torne o serviço público temporariamente ou use um túnel.

## WebSocket em Produção
- Use `wss://` no front-end: `wss://<DOMÍNIO>/ws/notifications?token=<JWT>`.
- O token JWT vem do `POST /auth/login` (`access_token`).
- Sem token válido, o servidor encerra com código `4401`.

## Testes Pós-Deploy
- API viva:
  - Acesse `https://<DOMÍNIO>/docs` para verificar o FastAPI.
- WebSocket:
  - Conecte com `wss://<DOMÍNIO>/ws/notifications?token=<JWT>` e logue mensagens.
- Despesa:
  - `POST /despesas/` com `destinatarios` contendo o `user_id` logado.
  - Deve receber `notificacao.despesa.criada` no WebSocket.
- Wishlist:
  - `POST /wishlist/` com `symbol` (ex.: `AAPL`, `PETR4.SA`, `BINANCE:BTCUSDT`) para um `grupo_id` do qual o usuário é membro.
  - Aguarde o intervalo (`WISHLIST_CHECK_INTERVAL`, padrão `60s`) e receba `notificacao.wishlist.preco_atingido.<grupo_id>` quando o preço atingir o alvo.
  - Expiração: inclua `data_limite` no item; ao passar do prazo, o sistema marca `expirado=true` e publica `notificacao.wishlist.prazo_expirado.<grupo_id>`.

## Migrações Alembic no Render
- Não existem comandos dentro do serviço de banco gerenciado. Rode as migrações a partir do seu Web Service ou via Job:
  - Post-Deploy Command no Web Service: `alembic upgrade head`.
  - Job (one-off):
    - Build: `pip install -r requirements.txt`
    - Start: `alembic upgrade head`
  - O `alembic/env.py` usa `DATABASE_URL` do ambiente; garanta que ela está definida no Web Service/Job.

## Troubleshooting — erro pydantic_core / Rust (maturin)
- Sintoma: falha ao instalar `pydantic_core` com logs do `maturin/cargo` e Python `3.13`.
- Causa: sem wheel pré-compilado para a versão do Python, pip tenta compilar com Rust num FS somente leitura.
- Solução rápida (Render recomenda definir versão de Python):
  1) Defina Python `3.12` no serviço:
     - Opção A: adicionar `.python-version` na raiz do repositório com `3.12.6`.
     - Opção B: setar env var `PYTHON_VERSION=3.12.6` no serviço.
     - Referência: Render Docs “Setting Your Python Version”.
  2) Mantenha `pydantic==2.5.0` e `pydantic_core==2.14.1` (há wheels para cp312 em Linux).
  3) Se usar Python `3.13`, use versões com wheels para cp313 (nem sempre disponíveis) ou Docker com toolchain Rust (não recomendado neste caso).

### Dica de configuração
- Em monorepo, garanta que o Web Service use `Root Directory: code/BackEnd`.

## Dicas e Boas Práticas
- Mantenha segredos no Render (Environment → Secret Files ou Env Vars).
- Combine serviços na mesma região para menor latência.
- Habilite autoscaling no Web Service se tiver picos de tráfego.
- Monitore logs do Web Service para conexões WebSocket e do consumidor MQ.
- Se usar CloudAMQP free, considere limites de conexão/mensagens.
- Não precisa definir `HOST`/`PORT` no Render para o serviço web; use o `$PORT` do ambiente no comando de start.

---

Com isso, você publica o back-end, aponta o banco e ativa a mensageria. Se quiser, eu crio também um `render.yaml` para declarar os serviços como Infra-as-Code.
