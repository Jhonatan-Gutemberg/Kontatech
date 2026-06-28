from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel


class GrupoCreate(BaseModel):
    nome: str


class GrupoUpdate(BaseModel):
    nome: Optional[str] = None


class GrupoMemberResponse(BaseModel):
    usuario_id: UUID
    is_admin: bool
    nome: Optional[str] = None
    email: Optional[str] = None


class GrupoResponse(BaseModel):
    id: UUID
    nome: str
    administrador_id: UUID
    membros: List[GrupoMemberResponse] = []

    class Config:
        from_attributes = True