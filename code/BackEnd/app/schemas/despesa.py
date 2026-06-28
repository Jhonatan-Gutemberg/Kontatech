from pydantic import BaseModel, Field, validator
from decimal import Decimal
from typing import List, Optional
from uuid import UUID
from datetime import date
from .divisao_despesa import DivisaoDespesaCreate, DivisaoDespesaResponse

class DespesaCreate(BaseModel):
    titulo: str = Field(..., min_length=1, max_length=100)
    descricao: Optional[str] = Field(None, max_length=500)
    valor_total: Decimal = Field(..., gt=0)
    data: date
    grupo_id: Optional[UUID] = None
    divisao: List[DivisaoDespesaCreate] = Field(..., min_items=1)
    
    @validator('divisao')
    def validar_divisao(cls, v, values):
        if 'valor_total' in values:
            soma_divisao = sum(item.valor_devido for item in v)
            if soma_divisao != values['valor_total']:
                raise ValueError(
                    f"A soma dos valores devidos ({soma_divisao}) deve ser igual ao valor total ({values['valor_total']})"
                )
        return v

class DespesaUpdate(BaseModel):
    titulo: Optional[str] = Field(None, min_length=1, max_length=100)
    descricao: Optional[str] = Field(None, max_length=500)
    valor_total: Optional[Decimal] = Field(None, gt=0)
    data: Optional[date] = None

class DespesaResponse(BaseModel):
    id: UUID
    titulo: str
    descricao: Optional[str]
    valor_total: Decimal
    data: date
    pagador_id: UUID
    grupo_id: Optional[UUID]
    data_criacao: date
    nome_pagador: Optional[str] = None
    nome_grupo: Optional[str] = None
    divisao: List[DivisaoDespesaResponse] = []
    
    class Config:
        from_attributes = True
