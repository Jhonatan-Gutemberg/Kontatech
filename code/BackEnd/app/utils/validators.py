from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from uuid import UUID
from ..models.usuario import Usuario
from ..models.grupo import Grupo
from ..models.despesa import Despesa
from ..models.grupo_usuario import GrupoUsuario
from decimal import Decimal

def validar_usuario_existe(db: Session, usuario_id: UUID) -> Usuario:
    """Valida se o usuário existe no banco"""
    usuario = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Usuário com ID {usuario_id} não encontrado"
        )
    return usuario

def validar_grupo_existe(db: Session, grupo_id: UUID) -> Grupo:
    """Valida se o grupo existe no banco"""
    grupo = db.query(Grupo).filter(Grupo.id == grupo_id).first()
    if not grupo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Grupo com ID {grupo_id} não encontrado"
        )
    return grupo

def validar_usuario_pertence_grupo(db: Session, usuario_id: UUID, grupo_id: UUID) -> bool:
    """Valida se o usuário pertence ao grupo"""
    membro = db.query(GrupoUsuario).filter(
        GrupoUsuario.usuario_id == usuario_id,
        GrupoUsuario.grupo_id == grupo_id
    ).first()
    
    if not membro:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuário não pertence ao grupo especificado"
        )
    return True

def validar_usuario_admin_grupo(db: Session, usuario_id: UUID, grupo_id: UUID) -> bool:
    """Valida se o usuário é administrador do grupo"""
    membro = db.query(GrupoUsuario).filter(
        GrupoUsuario.usuario_id == usuario_id,
        GrupoUsuario.grupo_id == grupo_id
    ).first()

    if not membro or not membro.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ação restrita a administradores do grupo"
        )
    return True

def validar_usuario_admin_original(db: Session, usuario_id: UUID, grupo_id: UUID) -> bool:
    """Valida se o usuário é o administrador original do grupo"""
    grupo = db.query(Grupo).filter(Grupo.id == grupo_id).first()
    if not grupo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Grupo com ID {grupo_id} não encontrado"
        )
    if str(grupo.administrador_id) != str(usuario_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ação restrita ao administrador original do grupo"
        )
    return True

def validar_despesa_existe(db: Session, despesa_id: UUID) -> Despesa:
    """Valida se a despesa existe no banco"""
    despesa = db.query(Despesa).filter(Despesa.id == despesa_id).first()
    if not despesa:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Despesa com ID {despesa_id} não encontrada"
        )
    return despesa

def validar_permissao_despesa(db: Session, despesa: Despesa, usuario_id: UUID) -> bool:
    """Valida se o usuário tem permissão para acessar/modificar a despesa"""
    # Se a despesa tem grupo, verificar se o usuário pertence ao grupo
    if despesa.grupo_id:
        return validar_usuario_pertence_grupo(db, usuario_id, despesa.grupo_id)
    
    # Se não tem grupo, apenas o pagador pode acessar
    if str(despesa.pagador_id) != str(usuario_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Você não tem permissão para acessar esta despesa"
        )
    
    return True

def validar_soma_divisao(valor_total: Decimal, divisao: list) -> bool:
    """Valida se a soma dos valores da divisão é igual ao valor total"""
    soma = sum(item.valor_devido for item in divisao)
    if soma != valor_total:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"A soma dos valores devidos ({soma}) deve ser igual ao valor total ({valor_total})"
        )
    return True
