import os


def test_health_endpoint(test_client):
    resp = test_client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "healthy"


def test_openapi_servers_uses_env_base_url(test_client):
    # Confirma que o OpenAPI expõe o servidor configurado pela variável de ambiente
    expected_url = os.environ.get("API_BASE_URL")
    assert expected_url, "API_BASE_URL deve estar definido nos testes"

    resp = test_client.get("/openapi.json")
    assert resp.status_code == 200
    spec = resp.json()
    assert "servers" in spec
    assert any(s.get("url") == expected_url for s in spec["servers"])