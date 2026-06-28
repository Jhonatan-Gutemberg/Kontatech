import os
import sys
from pathlib import Path
import pytest
from fastapi.testclient import TestClient

# Garantir que o diretório raiz (code/BackEnd) esteja no PYTHONPATH
ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))


@pytest.fixture(scope="session")
def test_client():
    # Definir base URL e banco para testes via variáveis de ambiente
    os.environ["API_BASE_URL"] = "http://test.local/api"
    os.environ["SECRET_KEY"] = "test-secret-key"
    # Observação: não definimos DATABASE_URL aqui para
    # usar o Postgres configurado em .env ou o padrão do projeto.

    # Importar a aplicação após definir variáveis de ambiente
    from app.main import app

    return TestClient(app)