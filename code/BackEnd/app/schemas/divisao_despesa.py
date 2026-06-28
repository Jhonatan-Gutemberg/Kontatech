from pydantic import BaseModel, Field
from decimal import Decimal
from typing import Optional
from uuid import UUID

class DivisaoDespesaCreate(BaseModel):
    usuario_id: UUID
    valor_devido: Decimal = Field(..., ge=0)

class DivisaoDespesaResponse(BaseModel):
    id: UUID
    usuario_id: UUID
    valor_devido: Decimal
    nome_usuario: Optional[str] = None
    
    class Config:
        from_attributes = True
