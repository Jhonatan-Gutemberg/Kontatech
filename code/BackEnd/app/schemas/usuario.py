from uuid import UUID

from pydantic import BaseModel, EmailStr
from decimal import Decimal
from typing import Optional


class UsuarioRegister(BaseModel):
    nome: str
    email: EmailStr
    senha: str


class UsuarioResponse(BaseModel):
    id: UUID
    nome: str
    email: EmailStr

    class Config:
        from_attributes = True


class UsuarioUpdate(BaseModel):
    nome: Optional[str] = None
    email: Optional[EmailStr] = None
    renda_mensal: Optional[Decimal] = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user_id: UUID