from datetime import date
from uuid import uuid4


def register_user(client, nome, email, senha):
    resp = client.post("/auth/register", json={"nome": nome, "email": email, "senha": senha})
    assert resp.status_code == 201
    return resp.json()


def login_user(client, email, senha):
    # OAuth2 usa form-urlencoded com username=email
    resp = client.post(
        "/auth/login",
        data={"username": email, "password": senha},
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    assert resp.status_code == 200
    token = resp.json()["access_token"]
    return token


def auth_headers(token):
    return {"Authorization": f"Bearer {token}"}


# Fluxo completo: cadastro, login, grupo, membro, despesa, listagem
def test_fluxo_cadastro_login_grupo_despesa_listagem(test_client):
    client = test_client

    # Registrar dois usuários
    email1 = f"alice+{uuid4().hex}@example.com"
    email2 = f"bob+{uuid4().hex}@example.com"
    u1 = register_user(client, "Alice", email1, "secret123")
    u2 = register_user(client, "Bob", email2, "secret123")

    # Login usuário 1
    token1 = login_user(client, email1, "secret123")

    # Criar grupo com usuário 1
    r = client.post("/grupos/", json={"nome": "Grupo Teste"}, headers=auth_headers(token1))
    assert r.status_code == 201
    grupo = r.json()
    grupo_id = grupo["id"]

    # Adicionar usuário 2 ao grupo
    r = client.post(f"/grupos/{grupo_id}/membros", json={"usuario_id": u2["id"]}, headers=auth_headers(token1))
    assert r.status_code == 201

    # Listar grupos do usuário 1
    r = client.get("/grupos/", headers=auth_headers(token1))
    assert r.status_code == 200
    grupos = r.json()
    assert any(g["id"] == grupo_id for g in grupos)

    # Criar despesa no grupo com divisão entre os dois
    hoje = date.today().isoformat()
    payload = {
        "titulo": "Compra Mercado",
        "descricao": "Teste",
        "valor_total": 100.0,
        "data": hoje,
        "grupo_id": grupo_id,
        "divisao": [
            {"usuario_id": u1["id"], "valor_devido": 60.0},
            {"usuario_id": u2["id"], "valor_devido": 40.0},
        ],
    }
    r = client.post("/despesas/", json=payload, headers=auth_headers(token1))
    assert r.status_code == 201
    despesa = r.json()
    assert float(despesa["valor_total"]) == 100.0
    assert len(despesa["divisao"]) == 2

    # Listar despesas do grupo
    r = client.get(f"/despesas/grupos/{grupo_id}/despesas", headers=auth_headers(token1))
    assert r.status_code == 200
    lista = r.json()
    assert len(lista) >= 1
    assert any(d["id"] == despesa["id"] for d in lista)
"""
Fluxo principal coberto por este teste:

- - - POST /auth/register para dois usuários.
    - POST /auth/login para obter Bearer token.
    - POST /grupos/ cria um grupo com o usuário logado.
    - POST /grupos/{grupo_id}/membros adiciona o segundo usuário.
    - POST /despesas/ cria uma despesa no grupo com divisão que soma ao total.
    - GET /despesas/grupos/{grupo_id}/despesas confirma a listagem.
"""


 


# Login com senha incorreta deve retornar 401
def test_login_senha_incorreta_retorna_401(test_client):
    client = test_client
    email = f"carol+{uuid4().hex}@example.com"
    # Registrar usuário
    reg = client.post("/auth/register", json={"nome": "Carol", "email": email, "senha": "correctpass"})
    assert reg.status_code == 201
    # Tentar login com senha incorreta
    bad = client.post(
        "/auth/login",
        data={"username": email, "password": "wrongpass"},
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    assert bad.status_code == 401


 


# Despesa inválida: soma da divisão ≠ valor_total retorna 422
def test_despesa_soma_divisao_invalida_retorna_422(test_client):
    client = test_client
    email1 = f"d1+{uuid4().hex}@example.com"
    email2 = f"d2+{uuid4().hex}@example.com"
    u1 = register_user(client, "U1", email1, "abc12345")
    u2 = register_user(client, "U2", email2, "abc12345")
    token1 = login_user(client, email1, "abc12345")
    r = client.post("/grupos/", json={"nome": "G Válido"}, headers=auth_headers(token1))
    assert r.status_code == 201
    grupo_id = r.json()["id"]
    r = client.post(f"/grupos/{grupo_id}/membros", json={"usuario_id": u2["id"]}, headers=auth_headers(token1))
    assert r.status_code == 201
    hoje = date.today().isoformat()
    payload = {
        "titulo": "Despesa Inválida",
        "descricao": "Divisão não confere",
        "valor_total": 100.0,
        "data": hoje,
        "grupo_id": grupo_id,
        "divisao": [
            {"usuario_id": u1["id"], "valor_devido": 30.0},
            {"usuario_id": u2["id"], "valor_devido": 50.0},  # Soma 80 != 100
        ],
    }
    r = client.post("/despesas/", json=payload, headers=auth_headers(token1))
    assert r.status_code == 422