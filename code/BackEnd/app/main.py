from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
from dotenv import load_dotenv

from .database import engine, Base
from .routers import despesas, auth, usuarios, grupos
from .routers import ws as ws_router
from .routers import debug_notifications as debug_router
from .events.mq import init_mq, close_mq, start_mq_consumer
from .settings import API_BASE_URL
from .models.wishlist_item import WishlistItem  # garante criação da tabela

# Carregar variáveis de ambiente
load_dotenv()

# Criar tabelas no banco de dados (inclui WishlistItem)
Base.metadata.create_all(bind=engine)

# Criar aplicação FastAPI
app = FastAPI(
    title="KontaTech - API",
    description="API para gerenciamento de despesas pessoais e em grupo",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    servers=[{"url": API_BASE_URL}]
)

# Configurar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Em produção, especifique os domínios permitidos
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Incluir routers
app.include_router(despesas.router)
app.include_router(auth.router)
app.include_router(usuarios.router)
app.include_router(grupos.router)
from .routers import wishlist
app.include_router(wishlist.router)
app.include_router(ws_router.router)
if os.getenv("DEBUG", "False").lower() == "true":
    app.include_router(debug_router.router)

@app.get("/")
async def root():
    """Endpoint raiz da API"""
    return {
        "message": "KontaTech - API",
        "version": "1.0.0",
        "docs": "/docs",
        "redoc": "/redoc"
    }

@app.get("/health")
async def health_check():
    """Endpoint para verificar a saúde da aplicação"""
    return {"status": "healthy", "message": "API funcionando corretamente"}


@app.on_event("startup")
async def on_startup():
    # Inicializa RabbitMQ (continua mesmo se MQ estiver indisponível)
    try:
        await init_mq(app)
    except Exception:
        # Em ambiente de desenvolvimento pode iniciar sem MQ
        pass

    # Inicializa conjunto de clientes WebSocket
    if not getattr(app.state, "ws_clients", None):
        app.state.ws_clients = set()
    # Inicializa mapa de clientes por usuário
    if not getattr(app.state, "ws_clients_by_user", None):
        app.state.ws_clients_by_user = {}

    # Inicia consumidor RabbitMQ em background para enviar mensagens aos WebSockets
    try:
        import asyncio
        asyncio.create_task(start_mq_consumer(app))
    except Exception:
        # Não bloqueia startup se MQ estiver indisponível
        pass

    # Inicia o verificador de preços da wishlist em background
    try:
        import asyncio
        from .workers.wishlist_price_checker import start_wishlist_price_checker
        # Em produção, 10 min; em dev, ajuste conforme necessidade
        interval_seconds = int(os.getenv("WISHLIST_CHECK_INTERVAL", "60"))
        asyncio.create_task(start_wishlist_price_checker(app, interval_seconds=interval_seconds))
    except Exception:
        # Não bloqueia startup se houver falha
        pass


@app.on_event("shutdown")
async def on_shutdown():
    # Fecha conexões RabbitMQ
    await close_mq(app)

if __name__ == "__main__":
    import uvicorn
    
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    debug = os.getenv("DEBUG", "False").lower() == "true"
    
    uvicorn.run(
        "app.main:app",
        host=host,
        port=port,
        reload=debug,
        log_level="info"
    )
