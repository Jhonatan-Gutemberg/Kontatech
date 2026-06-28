from app.main import app
from importlib import import_module
from fastapi.routing import APIRoute, WebSocketRoute

# tente importar o app de nomes comuns
candidates = ["main", "app", "server", "backend.main", "src.main"]
app = None
for name in candidates:
    try:
        mod = import_module(name)
        if hasattr(mod, "app"):
            app = getattr(mod, "app")
            break
    except Exception:
        continue

if app is None:
    raise SystemExit("Não foi possível importar a instância FastAPI 'app'. Ajuste os candidatos ou execute a partir da raiz do projeto.")

http_routes = []
ws_routes = []

for route in app.routes:
    # rota HTTP (APIRoute) — tem .methods e .endpoint
    if isinstance(route, APIRoute):
        path = route.path
        methods = ",".join(sorted(route.methods or []))
        endpoint_name = getattr(route.endpoint, "__name__", str(route.endpoint))
        http_routes.append((path, methods, endpoint_name))
    # rota WebSocket
    elif isinstance(route, WebSocketRoute):
        path = route.path
        endpoint_name = getattr(route.endpoint, "__name__", str(route.endpoint))
        ws_routes.append((path, endpoint_name))
    else:
        # fallback genérico (algumas rotas terceiras podem usar outras classes)
        path = getattr(route, "path", getattr(route, "path_regex", str(route)))
        if hasattr(route, "methods") and route.methods:
            methods = ",".join(sorted(route.methods))
            endpoint_name = getattr(route, "endpoint", getattr(route, "name", str(route)))
            http_routes.append((path, methods, endpoint_name))
        else:
            name = getattr(route, "name", getattr(route, "endpoint", str(route)))
            ws_routes.append((path, name))

print("=== HTTP ROUTES ===")
for path, methods, func in sorted(http_routes):
    print(f"{path} [{methods}] -> {func}")

print("\n=== WEBSOCKET ROUTES ===")
for path, name in sorted(ws_routes):
    print(f"{path} [WEBSOCKET] -> {name}")
