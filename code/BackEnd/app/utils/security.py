import os
from datetime import datetime, timedelta
from typing import Optional
import hashlib
import secrets

from jose import jwt
from dotenv import load_dotenv

load_dotenv()

# Configurações de segurança
SECRET_KEY = os.getenv("SECRET_KEY", "sua_chave_secreta_muito_segura_aqui")
ALGORITHM = os.getenv("ALGORITHM", "HS256")


def get_password_hash(password: str) -> str:
    """Gera o hash da senha usando SHA-256 com salt."""
    # Gerar um salt aleatório
    salt = secrets.token_hex(16)
    # Criar hash com salt
    password_hash = hashlib.sha256((password + salt).encode()).hexdigest()
    # Retornar salt + hash separados por $
    return f"{salt}${password_hash}"


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifica se a senha em texto corresponde ao hash armazenado."""
    try:
        # Separar salt e hash
        salt, stored_hash = hashed_password.split('$')
        # Gerar hash da senha fornecida com o mesmo salt
        password_hash = hashlib.sha256((plain_password + salt).encode()).hexdigest()
        # Comparar hashes
        return password_hash == stored_hash
    except ValueError:
        return False


def create_access_token(subject: str, expires_minutes: int = 60) -> str:
    """
    Cria um token JWT de acesso.

    - subject: identificador do usuário (id ou email), será usado em 'sub'
    - expires_minutes: tempo de expiração do token (padrão: 60 minutos)
    """
    expire = datetime.utcnow() + timedelta(minutes=expires_minutes)
    to_encode = {"sub": subject, "exp": expire}
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt