import os
import json
from fastapi import FastAPI
import aio_pika
from typing import Set, Dict, List
from starlette.websockets import WebSocket
import asyncio
from ..database import SessionLocal
from ..models.grupo_usuario import GrupoUsuario

RABBITMQ_URL = os.getenv("RABBITMQ_URL", "amqp://guest:guest@localhost:5672/")
EXCHANGE_NAME = "notifications"

# Configurações do Consumidor
CONSUMER_QUEUE_NAME = "backend_notifications_queue"
# A chave '#' garante que este consumidor receba todas as mensagens da exchange 'notifications'
NOTIFICATION_BINDING_KEY = "#" 


async def init_mq(app: FastAPI) -> None:
    """Inicializa conexão com RabbitMQ e declara a exchange de notificações."""
    try:
        connection = await aio_pika.connect_robust(RABBITMQ_URL)
        channel = await connection.channel()
        exchange = await channel.declare_exchange(
            EXCHANGE_NAME,
            aio_pika.ExchangeType.TOPIC,
            durable=True,
        )

        app.state.mq_conn = connection
        app.state.mq_channel = channel
        app.state.mq_exchange = exchange
    except Exception as e:
        print(f"Erro ao inicializar RabbitMQ: {e}")
        # O aplicativo pode continuar, mas sem MQ

async def close_mq(app: FastAPI) -> None:
    """Fecha recursos do RabbitMQ com segurança."""
    # A função start_mq_consumer adiciona 'mq_consumer' ao state
    consumer_tag = getattr(app.state, "mq_consumer", None)
    if consumer_tag:
        try:
            # Para o consumo antes de fechar o canal
            await consumer_tag.cancel()
        except Exception:
            pass

    try:
        channel = getattr(app.state, "mq_channel", None)
        if channel:
            await channel.close()
        connection = getattr(app.state, "mq_conn", None)
        if connection:
            await connection.close()
    except Exception:
        # Evita falhas no shutdown
        pass


async def publish_notification(app: FastAPI, routing_key: str, payload: dict) -> None:
    """Publica uma mensagem na exchange de notificações com roteamento por tópico."""
    exchange = getattr(app.state, "mq_exchange", None)
    if not exchange:
        print("Aviso: RabbitMQ não inicializado. Notificação não publicada.")
        return

    body = json.dumps(payload).encode("utf-8")
    message = aio_pika.Message(
        body=body,
        content_type="application/json",
        delivery_mode=aio_pika.DeliveryMode.PERSISTENT,
    )
    try:
        await exchange.publish(message, routing_key=routing_key)
    except Exception as e:
        print(f"Erro ao publicar notificação: {e}")


async def start_mq_consumer(app: FastAPI) -> None:
    """Inicia um consumidor RabbitMQ que encaminha mensagens para clientes WebSocket conectados."""
    channel = getattr(app.state, "mq_channel", None)
    exchange = getattr(app.state, "mq_exchange", None)
    if not channel or not exchange:
        return

    # Declara uma fila que recebe todas as notificações
    queue = await channel.declare_queue("notif.broadcast", durable=True)
    await queue.bind(exchange, routing_key="notificacao.#")

    async def _on_message(message: aio_pika.IncomingMessage) -> None:
        async with message.process(requeue=False):
            try:
                payload = json.loads(message.body.decode("utf-8"))
                routing_key = message.routing_key or ""
                clients_by_user: Dict[str, Set[WebSocket]] = getattr(app.state, "ws_clients_by_user", {})

                # Determinar destinatários pelo tipo de notificação
                target_user_ids: List[str] = []

                # Despesas: destinatários explícitos no payload
                if routing_key.startswith("notificacao.despesa."):
                    dests = payload.get("destinatarios") or []
                    target_user_ids.extend([str(u) for u in dests])

                # Wishlist por grupo: enviar a todos os membros do grupo
                elif routing_key.startswith("notificacao.wishlist.preco_atingido."):
                    grupo_id = payload.get("grupo_id")
                    if not grupo_id:
                        # tenta extrair do routing_key
                        try:
                            grupo_id = routing_key.split(".")[-1]
                        except Exception:
                            grupo_id = None
                    if grupo_id:
                        db = SessionLocal()
                        try:
                            membros = db.query(GrupoUsuario).filter(GrupoUsuario.grupo_id == grupo_id).all()
                            target_user_ids.extend([str(m.usuario_id) for m in membros])
                        except Exception:
                            try:
                                db.rollback()
                            except Exception:
                                pass
                        finally:
                            db.close()

                # Se houver destinatários, envia apenas para eles
                sent_errors: List[WebSocket] = []
                for uid in set(target_user_ids):
                    sockets = clients_by_user.get(uid, set())
                    for ws in list(sockets):
                        try:
                            await ws.send_json({"routing_key": routing_key, "data": payload})
                        except Exception:
                            sent_errors.append(ws)

                # Remove sockets desconectados dos conjuntos de usuários
                for ws in sent_errors:
                    try:
                        for u, s in list(clients_by_user.items()):
                            if ws in s:
                                try:
                                    s.discard(ws)
                                except Exception:
                                    pass
                                if len(s) == 0:
                                    try:
                                        del clients_by_user[u]
                                    except Exception:
                                        pass
                    except Exception:
                        pass
            except Exception:
                # Caso a mensagem esteja malformada, evita requeue infinito
                pass

    await queue.consume(_on_message)

    # Mantém a task viva em background
    await asyncio.Event().wait()