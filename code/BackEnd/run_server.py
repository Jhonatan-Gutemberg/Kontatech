#!/usr/bin/env python3
"""
Script simples para rodar o servidor FastAPI
"""

import uvicorn
from app.main import app

if __name__ == "__main__":
    print("🚀 Iniciando servidor FastAPI...")
    print("📍 Acesse: http://localhost:8000")
    print("📚 Documentação: http://localhost:8000/docs")
    print("🛑 Para parar: Ctrl+C")
    
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )