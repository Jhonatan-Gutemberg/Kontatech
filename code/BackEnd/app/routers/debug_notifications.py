from fastapi import APIRouter, Request
from fastapi import Body
from typing import Any, Dict
from ..events.mq import publish_notification

router = APIRouter(prefix="/debug", tags=["debug"])


@router.post("/notifications")
async def debug_publish_notification(request: Request, payload: Dict[str, Any] = Body(...), routing_key: str = "notificacao.teste.broadcast"):
    """Endpoint de debug para publicar uma notificação no RabbitMQ.
    Disponível apenas em ambiente com DEBUG=true.
    """
    await publish_notification(request.app, routing_key=routing_key, payload=payload)
    return {"status": "published", "routing_key": routing_key, "payload": payload}