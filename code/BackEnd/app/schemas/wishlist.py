from pydantic import BaseModel, Field
from decimal import Decimal
from typing import Optional
from uuid import UUID
from datetime import datetime


class WishlistCreate(BaseModel):
    grupo_id: UUID
    symbol: str = Field(..., min_length=1)
    preco_alvo: Decimal = Field(..., gt=0)
    titulo: Optional[str] = Field(None, max_length=200)
    data_limite: Optional[datetime] = Field(None, description="Data limite para monitoramento")


class WishlistResponse(BaseModel):
    id: UUID
    grupo_id: UUID
    symbol: str
    provider: str
    titulo: Optional[str]
    preco_alvo: Decimal
    preco_atual: Optional[Decimal]
    atingido: bool
    expirado: bool
    data_criacao: datetime
    data_limite: Optional[datetime]

    class Config:
        from_attributes = True