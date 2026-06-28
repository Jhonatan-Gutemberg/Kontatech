from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Set, Dict
from ..utils.auth import verify_token

router = APIRouter(prefix="/ws", tags=["websocket"])


@router.websocket("/notifications")
async def websocket_notifications(websocket: WebSocket):
    """Canal WebSocket para receber notificações direcionadas em tempo real.

    Autenticação: enviar `token` JWT como query string (ex.: /ws/notifications?token=SEU_JWT).
    """
    # Autenticação simples via token na query
    token = websocket.query_params.get("token")
    if not token:
        # Recusa conexão se não houver token
        await websocket.close(code=4401)
        return

    payload = verify_token(token)
    if not payload or not payload.get("sub"):
        await websocket.close(code=4401)
        return

    user_id = str(payload["sub"])

    await websocket.accept()

    # Acesso à instância do app via websocket scope
    app = websocket.app

    # Mapa de clientes por usuário
    clients_by_user: Dict[str, Set[WebSocket]] = getattr(app.state, "ws_clients_by_user", None)
    if clients_by_user is None:
        clients_by_user = {}
        app.state.ws_clients_by_user = clients_by_user

    # Adiciona o websocket ao conjunto do usuário
    user_set = clients_by_user.get(user_id)
    if user_set is None:
        user_set = set()
        clients_by_user[user_id] = user_set
    user_set.add(websocket)

    try:
        # Mantém a conexão ativa; lê mensagens de ping do cliente se houver
        while True:
            # Opcional: ler para detectar desconexão; não processamos conteúdo do cliente
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    except Exception:
        # Evita quebra silenciosa por erros
        pass
    finally:
        try:
            # Remove o websocket do conjunto do usuário
            try:
                user_set.discard(websocket)
            except Exception:
                pass

            # Se ficar vazio, remove a chave
            if clients_by_user.get(user_id) and len(clients_by_user[user_id]) == 0:
                try:
                    del clients_by_user[user_id]
                except Exception:
                    pass
        except Exception:
            pass