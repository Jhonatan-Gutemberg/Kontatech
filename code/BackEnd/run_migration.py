"""
Script para executar a migração que adiciona os campos de prazo limite na wishlist.
Execute este script uma única vez para atualizar o banco de dados.

Uso: python run_migration.py
"""

from app.database import engine
from sqlalchemy import text

def run_migration():
    print("🔄 Iniciando migração do banco de dados...")
    print("=" * 50)
    
    try:
        with engine.connect() as conn:
            # Adiciona coluna 'expirado'
            print("➕ Adicionando coluna 'expirado'...")
            conn.execute(text('''
                ALTER TABLE wishlist_itens 
                ADD COLUMN IF NOT EXISTS expirado BOOLEAN NOT NULL DEFAULT FALSE;
            '''))
            print("   ✅ Coluna 'expirado' adicionada!")
            
            # Adiciona coluna 'data_limite'
            print("➕ Adicionando coluna 'data_limite'...")
            conn.execute(text('''
                ALTER TABLE wishlist_itens 
                ADD COLUMN IF NOT EXISTS data_limite TIMESTAMP WITH TIME ZONE;
            '''))
            print("   ✅ Coluna 'data_limite' adicionada!")
            
            # Commit das alterações
            conn.commit()
            
        print("=" * 50)
        print("🎉 Migração concluída com sucesso!")
        print("")
        print("Agora você pode reiniciar o backend com: python run_server.py")
        
    except Exception as e:
        print(f"❌ Erro durante a migração: {e}")
        print("")
        print("Possíveis soluções:")
        print("1. Verifique se o banco de dados está rodando")
        print("2. Verifique se a variável DATABASE_URL está correta no .env")
        print("3. Verifique se a tabela 'wishlist_itens' existe")
        raise

if __name__ == "__main__":
    run_migration()

