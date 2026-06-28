from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from decimal import Decimal

from ..database import get_db
from ..models.despesa import Despesa
from ..models.divisao_despesa import DivisaoDespesa
from ..schemas.despesa import DespesaCreate, DespesaUpdate, DespesaResponse
from ..schemas.divisao_despesa import DivisaoDespesaResponse
from ..utils.auth import get_current_user, get_current_user_id
from ..utils.validators import (
    validar_usuario_existe, 
    validar_grupo_existe, 
    validar_usuario_pertence_grupo,
    validar_despesa_existe,
    validar_permissao_despesa,
    validar_soma_divisao
)

router = APIRouter(prefix="/despesas", tags=["despesas"])

@router.post("/", response_model=DespesaResponse, status_code=status.HTTP_201_CREATED)
async def criar_despesa(
    despesa_data: DespesaCreate,
    current_user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    request: Request = None,
):
    """
    Cria uma nova despesa.
    
    - O pagador_id é automaticamente definido como o ID do usuário autenticado
    - Valida se a soma dos valores da divisão é igual ao valor total
    - Cria a despesa e suas divisões em uma transação atômica
    """
    try:
        # Validar se o grupo existe (se fornecido)
        if despesa_data.grupo_id:
            grupo = validar_grupo_existe(db, despesa_data.grupo_id)
            # Validar se o usuário pertence ao grupo
            validar_usuario_pertence_grupo(db, UUID(current_user_id), despesa_data.grupo_id)
        
        # Validar se todos os usuários da divisão existem
        for divisao_item in despesa_data.divisao:
            validar_usuario_existe(db, divisao_item.usuario_id)
        
        # Validar soma da divisão
        validar_soma_divisao(despesa_data.valor_total, despesa_data.divisao)
        
        # Criar a despesa
        db_despesa = Despesa(
            titulo=despesa_data.titulo,
            descricao=despesa_data.descricao,
            valor_total=despesa_data.valor_total,
            data=despesa_data.data,
            pagador_id=UUID(current_user_id),
            grupo_id=despesa_data.grupo_id
        )
        
        db.add(db_despesa)
        db.flush()  # Para obter o ID da despesa
        
        # Criar as divisões
        for divisao_item in despesa_data.divisao:
            db_divisao = DivisaoDespesa(
                despesa_id=db_despesa.id,
                usuario_id=divisao_item.usuario_id,
                valor_devido=divisao_item.valor_devido
            )
            db.add(db_divisao)
        
        db.commit()
        db.refresh(db_despesa)

        # Publicar evento de notificação: despesa criada
        try:
            from ..events.mq import publish_notification
            # Determinar destinatários com base na divisão da despesa
            destinatarios = [str(d.usuario_id) for d in db.query(DivisaoDespesa).filter(DivisaoDespesa.despesa_id == db_despesa.id).all()]
            payload = {
                "despesa_id": str(db_despesa.id),
                "grupo_id": str(db_despesa.grupo_id) if db_despesa.grupo_id else None,
                "pagador_id": str(db_despesa.pagador_id),
                "destinatarios": destinatarios,
                "valor_total": float(db_despesa.valor_total),
                "titulo": db_despesa.titulo,
                "descricao": db_despesa.descricao,
            }
            await publish_notification(request.app, "notificacao.despesa.criada", payload)
        except Exception:
            # Não falhar a criação da despesa caso MQ esteja indisponível
            pass

        # Buscar dados relacionados para a resposta
        return buscar_despesa_completa(db, db_despesa.id)
        
    except Exception as e:
        db.rollback()
        raise e

@router.get("/{despesa_id}", response_model=DespesaResponse)
def obter_despesa(
    despesa_id: UUID,
    current_user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Obtém os detalhes completos de uma despesa.
    
    - Verifica se o usuário tem permissão para acessar a despesa
    - Retorna os dados da despesa com suas divisões
    """
    # Buscar e validar a despesa
    despesa = validar_despesa_existe(db, despesa_id)
    
    # Validar permissão
    validar_permissao_despesa(db, despesa, UUID(current_user_id))
    
    return buscar_despesa_completa(db, despesa_id)

@router.get("/grupos/{grupo_id}/despesas", response_model=List[DespesaResponse])
def listar_despesas_grupo(
    grupo_id: UUID,
    current_user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Lista todas as despesas de um grupo específico.
    
    - Verifica se o usuário pertence ao grupo
    - Retorna lista de despesas com suas divisões
    """
    # Validar se o grupo existe
    grupo = validar_grupo_existe(db, grupo_id)
    
    # Validar se o usuário pertence ao grupo
    validar_usuario_pertence_grupo(db, UUID(current_user_id), grupo_id)
    
    # Buscar despesas do grupo
    despesas = db.query(Despesa).filter(Despesa.grupo_id == grupo_id).all()
    
    # Retornar despesas com dados completos
    return [buscar_despesa_completa(db, despesa.id) for despesa in despesas]

@router.put("/{despesa_id}", response_model=DespesaResponse)
def atualizar_despesa(
    despesa_id: UUID,
    despesa_update: DespesaUpdate,
    current_user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Atualiza uma despesa existente.
    
    - Verifica se o usuário tem permissão para modificar a despesa
    - Atualiza apenas os campos fornecidos
    """
    # Buscar e validar a despesa
    despesa = validar_despesa_existe(db, despesa_id)
    
    # Validar permissão (apenas o pagador pode editar)
    if str(despesa.pagador_id) != current_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas o pagador pode editar esta despesa"
        )
    
    # Atualizar campos fornecidos
    update_data = despesa_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(despesa, field, value)
    
    db.commit()
    db.refresh(despesa)
    
    return buscar_despesa_completa(db, despesa_id)

@router.delete("/{despesa_id}", status_code=status.HTTP_204_NO_CONTENT)
def excluir_despesa(
    despesa_id: UUID,
    current_user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Exclui uma despesa e suas divisões.
    
    - Verifica se o usuário tem permissão para excluir a despesa
    - Exclui automaticamente todas as divisões relacionadas (cascade)
    """
    # Buscar e validar a despesa
    despesa = validar_despesa_existe(db, despesa_id)
    
    # Validar permissão (apenas o pagador pode excluir)
    if str(despesa.pagador_id) != current_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas o pagador pode excluir esta despesa"
        )
    
    # Excluir a despesa (as divisões serão excluídas automaticamente por cascade)
    db.delete(despesa)
    db.commit()

def buscar_despesa_completa(db: Session, despesa_id: UUID) -> DespesaResponse:
    """
    Função auxiliar para buscar uma despesa com todos os dados relacionados.
    """
    despesa = db.query(Despesa).filter(Despesa.id == despesa_id).first()
    
    if not despesa:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Despesa não encontrada"
        )
    
    # Buscar divisões com dados do usuário
    divisoes = []
    for divisao in despesa.divisoes:
        usuario = db.query(despesa.pagador.__class__).filter(
            despesa.pagador.__class__.id == divisao.usuario_id
        ).first()
        
        divisoes.append(DivisaoDespesaResponse(
            id=divisao.id,
            usuario_id=divisao.usuario_id,
            valor_devido=divisao.valor_devido,
            nome_usuario=usuario.nome if usuario else None
        ))
    
    return DespesaResponse(
        id=despesa.id,
        titulo=despesa.titulo,
        descricao=despesa.descricao,
        valor_total=despesa.valor_total,
        data=despesa.data,
        pagador_id=despesa.pagador_id,
        grupo_id=despesa.grupo_id,
        data_criacao=despesa.data_criacao.date(),
        nome_pagador=despesa.pagador.nome if despesa.pagador else None,
        nome_grupo=despesa.grupo.nome if despesa.grupo else None,
        divisao=divisoes
    )
