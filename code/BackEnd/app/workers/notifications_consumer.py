import asyncio
import json
import os
import aio_pika

RABBITMQ_URL = os.getenv("RABBITMQ_URL", "amqp://guest:guest@localhost:5672/")
EXCHANGE_NAME = "notifications"


async def handle_message(message: aio_pika.IncomingMessage) -> None:
    async with message.process(requeue=False):
        try:
            payload = json.loads(message.body.decode("utf-8"))
            routing_key = message.routing_key or ""
            # Aqui você integra o canal de entrega (WebSocket/SSE/FCM/email)
            print(f"[Worker] Mensagem recebida: {routing_key} -> {payload}")
            # Exemplo: if routing_key.startswith("notificacao.despesa"):
            #   enviar_notificacao_despesa(payload)
        except Exception as e:
            print(f"[Worker] Erro ao processar mensagem: {e}")
            # message.nack() é chamado automaticamente pelo process(requeue=False) quando exceção é levantada


async def main() -> None:
    connection = await aio_pika.connect_robust(RABBITMQ_URL)
    channel = await connection.channel()

    exchange = await channel.declare_exchange(
        EXCHANGE_NAME,
        aio_pika.ExchangeType.TOPIC,
        durable=True,
    )

    # Fila de notificações de despesas
    despesas_queue = await channel.declare_queue("notif.despesas", durable=True)
    await despesas_queue.bind(exchange, routing_key="notificacao.despesa.*")

    # Fila de notificações de preços (para futuro uso)
    precos_queue = await channel.declare_queue("notif.precos", durable=True)
    await precos_queue.bind(exchange, routing_key="notificacao.preco.*")

    print("[Worker] Consumindo filas: notif.despesas, notif.precos")
    await despesas_queue.consume(handle_message)
    await precos_queue.consume(handle_message)

    try:
        # Mantém o processo vivo
        await asyncio.Event().wait()
    finally:
        await channel.close()
        await connection.close()


if __name__ == "__main__":
    asyncio.run(main())