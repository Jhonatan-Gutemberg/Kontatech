from uuid import UUID
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..models.usuario import Usuario
from ..models.grupo_usuario import GrupoUsuario
from ..models.divisao_despesa import DivisaoDespesa
from ..models.despesa import Despesa
from ..schemas.usuario import UsuarioResponse, UsuarioUpdate
from ..utils.auth import get_current_user_id


router = APIRouter(prefix="/usuarios", tags=["usuarios"]) 


@router.get("/", response_model=List[UsuarioResponse])
def listar_usuarios(
    current_user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Lista todos os usuários.

    Requer autenticação. Não retorna campos sensíveis.
    """
    users = db.query(Usuario).all()
    return [UsuarioResponse(id=u.id, nome=u.nome, email=u.email) for u in users]


@router.get("/{usuario_id}", response_model=UsuarioResponse)
def obter_usuario_por_id(
    usuario_id: UUID,
    current_user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """Obtém um usuário por ID. Requer autenticação."""
    user = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuário não encontrado")
    return UsuarioResponse(id=user.id, nome=user.nome, email=user.email)


@router.get("/email/{email}", response_model=UsuarioResponse)
def obter_usuario_por_email(
    email: str,
    current_user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """Obtém um usuário por e-mail. Requer autenticação."""
    user = db.query(Usuario).filter(Usuario.email == email).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuário não encontrado")
    return UsuarioResponse(id=user.id, nome=user.nome, email=user.email)


@router.put("/{usuario_id}", response_model=UsuarioResponse)
@router.patch("/{usuario_id}", response_model=UsuarioResponse)
def atualizar_usuario(
    usuario_id: UUID,
    update_data: UsuarioUpdate,
    current_user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Atualiza dados do usuário. Apenas o próprio usuário pode atualizar.
    Valida e-mail único se alterado.
    """
    if str(usuario_id) != current_user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Você só pode atualizar sua própria conta")

    user = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuário não encontrado")

    # Validar e-mail único se alterado
    if update_data.email and update_data.email != user.email:
        exists = db.query(Usuario).filter(Usuario.email == update_data.email).first()
        if exists:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email já cadastrado")
        user.email = update_data.email

    if update_data.nome is not None:
        user.nome = update_data.nome

    if update_data.renda_mensal is not None:
        user.renda_mensal = update_data.renda_mensal

    db.commit()
    db.refresh(user)
    return UsuarioResponse(id=user.id, nome=user.nome, email=user.email)


@router.delete("/{usuario_id}", status_code=status.HTTP_204_NO_CONTENT)
def excluir_usuario(
    usuario_id: UUID,
    current_user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Exclui a própria conta do usuário.

    - Permite exclusão apenas se o usuário não for pagador em despesas
    - Remove participações em grupos e divisões de despesas do usuário
    """
    if str(usuario_id) != current_user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Você só pode excluir sua própria conta")

    user = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuário não encontrado")

    # Bloquear exclusão se usuário for pagador em alguma despesa
    has_paid_expenses = db.query(Despesa).filter(Despesa.pagador_id == usuario_id).first()
    if has_paid_expenses:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Não é possível excluir: usuário possui despesas registradas como pagador"
        )

    try:
        # Remover participações em grupos
        db.query(GrupoUsuario).filter(GrupoUsuario.usuario_id == usuario_id).delete()
        # Remover divisões de despesas do usuário
        db.query(DivisaoDespesa).filter(DivisaoDespesa.usuario_id == usuario_id).delete()
        # Excluir usuário
        db.delete(user)
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Erro ao excluir usuário")

    return None