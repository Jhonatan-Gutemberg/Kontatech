#!/usr/bin/env python3
"""
Exemplo de uso da API KontaTech
Este arquivo demonstra como usar os endpoints da API
"""

import requests
import json
from uuid import UUID
from datetime import date

# Configurações
BASE_URL = "http://localhost:8000/api/v1"
TOKEN_JWT = "seu_token_jwt_aqui"  # Substitua pelo token real

# Headers para autenticação
headers = {
    "Authorization": f"Bearer {TOKEN_JWT}",
    "Content-Type": "application/json"
}

def exemplo_criar_despesa():
    """Exemplo de como criar uma nova despesa"""
    
    # Dados da despesa
    dados_despesa = {
        "titulo": "Almoço em Grupo",
        "descricao": "Almoço no restaurante italiano",
        "valor_total": 150.00,
        "data": "2024-01-15",
        "grupo_id": "123e4567-e89b-12d3-a456-426614174000",  # UUID do grupo
        "divisao": [
            {
                "usuario_id": "123e4567-e89b-12d3-a456-426614174001",  # UUID do usuário 1
                "valor_devido": 50.00
            },
            {
                "usuario_id": "123e4567-e89b-12d3-a456-426614174002",  # UUID do usuário 2
                "valor_devido": 100.00
            }
        ]
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/despesas/",
            headers=headers,
            json=dados_despesa
        )
        
        if response.status_code == 201:
            despesa_criada = response.json()
            print("✅ Despesa criada com sucesso!")
            print(f"ID da despesa: {despesa_criada['id']}")
            print(f"Título: {despesa_criada['titulo']}")
            print(f"Valor total: R$ {despesa_criada['valor_total']}")
            return despesa_criada['id']
        else:
            print(f"❌ Erro ao criar despesa: {response.status_code}")
            print(response.text)
            return None
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Erro de conexão: {e}")
        return None

def exemplo_obter_despesa(despesa_id):
    """Exemplo de como obter detalhes de uma despesa"""
    
    try:
        response = requests.get(
            f"{BASE_URL}/despesas/{despesa_id}",
            headers=headers
        )
        
        if response.status_code == 200:
            despesa = response.json()
            print("\n📋 Detalhes da Despesa:")
            print(f"ID: {despesa['id']}")
            print(f"Título: {despesa['titulo']}")
            print(f"Descrição: {despesa['descricao']}")
            print(f"Valor Total: R$ {despesa['valor_total']}")
            print(f"Data: {despesa['data']}")
            print(f"Pagador: {despesa['nome_pagador']}")
            print(f"Grupo: {despesa['nome_grupo']}")
            
            print("\n👥 Divisão da Despesa:")
            for divisao in despesa['divisao']:
                print(f"  - {divisao['nome_usuario']}: R$ {divisao['valor_devido']}")
                
        else:
            print(f"❌ Erro ao obter despesa: {response.status_code}")
            print(response.text)
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Erro de conexão: {e}")

def exemplo_listar_despesas_grupo(grupo_id):
    """Exemplo de como listar despesas de um grupo"""
    
    try:
        response = requests.get(
            f"{BASE_URL}/despesas/grupos/{grupo_id}/despesas",
            headers=headers
        )
        
        if response.status_code == 200:
            despesas = response.json()
            print(f"\n📊 Despesas do Grupo (Total: {len(despesas)}):")
            
            for despesa in despesas:
                print(f"\n  🏷️  {despesa['titulo']}")
                print(f"     💰 R$ {despesa['valor_total']}")
                print(f"     📅 {despesa['data']}")
                print(f"     👤 Pagador: {despesa['nome_pagador']}")
                
        else:
            print(f"❌ Erro ao listar despesas: {response.status_code}")
            print(response.text)
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Erro de conexão: {e}")

def exemplo_atualizar_despesa(despesa_id):
    """Exemplo de como atualizar uma despesa"""
    
    dados_atualizacao = {
        "titulo": "Almoço em Grupo - Atualizado",
        "descricao": "Almoço no restaurante italiano - descrição atualizada",
        "valor_total": 160.00,
        "data": "2024-01-16"
    }
    
    try:
        response = requests.put(
            f"{BASE_URL}/despesas/{despesa_id}",
            headers=headers,
            json=dados_atualizacao
        )
        
        if response.status_code == 200:
            despesa_atualizada = response.json()
            print("✅ Despesa atualizada com sucesso!")
            print(f"Novo título: {despesa_atualizada['titulo']}")
            print(f"Novo valor: R$ {despesa_atualizada['valor_total']}")
        else:
            print(f"❌ Erro ao atualizar despesa: {response.status_code}")
            print(response.text)
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Erro de conexão: {e}")

def exemplo_excluir_despesa(despesa_id):
    """Exemplo de como excluir uma despesa"""
    
    try:
        response = requests.delete(
            f"{BASE_URL}/despesas/{despesa_id}",
            headers=headers
        )
        
        if response.status_code == 204:
            print("✅ Despesa excluída com sucesso!")
        else:
            print(f"❌ Erro ao excluir despesa: {response.status_code}")
            print(response.text)
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Erro de conexão: {e}")

def main():
    """Função principal com exemplos de uso"""
    
    print("=" * 60)
    print("EXEMPLO DE USO DA API KONTATECH")
    print("=" * 60)
    
    print("\n⚠️  IMPORTANTE:")
    print("1. Certifique-se de que o servidor está rodando em http://localhost:8000")
    print("2. Substitua TOKEN_JWT por um token válido")
    print("3. Substitua os UUIDs pelos IDs reais do seu banco de dados")
    
    print("\n" + "=" * 60)
    
    # Exemplo 1: Criar despesa
    print("1️⃣  Criando uma nova despesa...")
    despesa_id = exemplo_criar_despesa()
    
    if despesa_id:
        # Exemplo 2: Obter detalhes da despesa
        print("\n2️⃣  Obtendo detalhes da despesa...")
        exemplo_obter_despesa(despesa_id)
        
        # Exemplo 3: Listar despesas do grupo
        print("\n3️⃣  Listando despesas do grupo...")
        grupo_id = "123e4567-e89b-12d3-a456-426614174000"  # UUID do grupo
        exemplo_listar_despesas_grupo(grupo_id)
        
        # Exemplo 4: Atualizar despesa
        print("\n4️⃣  Atualizando a despesa...")
        exemplo_atualizar_despesa(despesa_id)
        
        # Exemplo 5: Excluir despesa
        print("\n5️⃣  Excluindo a despesa...")
        exemplo_excluir_despesa(despesa_id)
    
    print("\n" + "=" * 60)
    print("Exemplos concluídos!")

if __name__ == "__main__":
    main()
