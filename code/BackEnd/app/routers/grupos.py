from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel

from ..database import get_db
from ..utils.auth import get_current_user_id
from ..utils.validators import (
    validar_usuario_pertence_grupo,
    validar_usuario_admin_grupo,
    validar_usuario_admin_original,
)
from ..models.grupo import Grupo
from ..models.grupo_usuario import GrupoUsuario
from ..models.usuario import Usuario
from ..schemas.grupo import (
    GrupoCreate,
    GrupoUpdate,
    GrupoResponse,
    GrupoMemberResponse,
)


router = APIRouter(prefix="/grupos", tags=["grupos"])


def _grupo_to_response(db: Session, grupo: Grupo) -> GrupoResponse:
    membros_rel = (
        db.query(GrupoUsuario)
        .filter(GrupoUsuario.grupo_id == grupo.id)
        .all()
    )
    membros: List[GrupoMemberResponse] = []
    for rel in membros_rel:
        usuario = db.query(Usuario).filter(Usuario.id == rel.usuario_id).first()
        membros.append(
            GrupoMemberResponse(
                usuario_id=rel.usuario_id,
                is_admin=rel.is_admin,
                nome=usuario.nome if usuario else None,
                email=usuario.email if usuario else None,
            )
        )

    return GrupoResponse(
        id=grupo.id,
        nome=grupo.nome,
        administrador_id=grupo.administrador_id,
        membros=membros,
    )


@router.post("/", response_model=GrupoResponse, status_code=status.HTTP_201_CREATED)
def criar_grupo(
    payload: GrupoCreate,
    db: Session = Depends(get_db),
    current_user_id: str = Depends(get_current_user_id),
):
    from uuid import UUID as _UUID
    grupo = Grupo(nome=payload.nome, administrador_id=_UUID(current_user_id))
    db.add(grupo)
    db.flush()  # obter id do grupo antes de criar relação

    rel = GrupoUsuario(usuario_id=_UUID(current_user_id), grupo_id=grupo.id, is_admin=True)
    db.add(rel)
    db.commit()
    db.refresh(grupo)
    return _grupo_to_response(db, grupo)


@router.get("/", response_model=List[GrupoResponse])
def listar_grupos(
    db: Session = Depends(get_db),
    current_user_id: str = Depends(get_current_user_id),
):
    from uuid import UUID as _UUID
    grupos_ids = (
        db.query(GrupoUsuario.grupo_id)
        .filter(GrupoUsuario.usuario_id == _UUID(current_user_id))
        .all()
    )
    ids = [gid for (gid,) in grupos_ids]
    grupos = db.query(Grupo).filter(Grupo.id.in_(ids)).all()
    return [_grupo_to_response(db, g) for g in grupos]


@router.get("/{grupo_id}", response_model=GrupoResponse)
def obter_grupo(
    grupo_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: str = Depends(get_current_user_id),
):
    from uuid import UUID as _UUID
    validar_usuario_pertence_grupo(db, _UUID(current_user_id), grupo_id)
    grupo = db.query(Grupo).filter(Grupo.id == grupo_id).first()
    if not grupo:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Grupo não encontrado")
    return _grupo_to_response(db, grupo)


@router.patch("/{grupo_id}", response_model=GrupoResponse)
def atualizar_grupo(
    grupo_id: UUID,
    payload: GrupoUpdate,
    db: Session = Depends(get_db),
    current_user_id: str = Depends(get_current_user_id),
):
    from uuid import UUID as _UUID
    validar_usuario_admin_grupo(db, _UUID(current_user_id), grupo_id)
    grupo = db.query(Grupo).filter(Grupo.id == grupo_id).first()
    if not grupo:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Grupo não encontrado")

    if payload.nome is not None:
        grupo.nome = payload.nome

    db.commit()
    db.refresh(grupo)
    return _grupo_to_response(db, grupo)


@router.delete("/{grupo_id}", status_code=status.HTTP_204_NO_CONTENT)
def excluir_grupo(
    grupo_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: str = Depends(get_current_user_id),
):
    from uuid import UUID as _UUID
    validar_usuario_admin_original(db, _UUID(current_user_id), grupo_id)
    grupo = db.query(Grupo).filter(Grupo.id == grupo_id).first()
    if not grupo:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Grupo não encontrado")

    # Bloquear exclusão se houver despesas associadas
    ha_despesas = db.query(Grupo).join(Grupo.despesas).filter(Grupo.id == grupo_id).first()
    if ha_despesas:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Grupo não pode ser excluído: há despesas associadas",
        )

    db.delete(grupo)
    db.commit()
    return None


class MembroInput(BaseModel):
    usuario_id: UUID


@router.post("/{grupo_id}/membros", status_code=status.HTTP_201_CREATED)
def adicionar_membro(
    grupo_id: UUID,
    body: MembroInput,
    db: Session = Depends(get_db),
    current_user_id: str = Depends(get_current_user_id),
):
    from uuid import UUID as _UUID
    validar_usuario_admin_grupo(db, _UUID(current_user_id), grupo_id)
    usuario = db.query(Usuario).filter(Usuario.id == body.usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuário não encontrado")

    # Verificar se já é membro
    existente = (
        db.query(GrupoUsuario)
        .filter(GrupoUsuario.usuario_id == body.usuario_id, GrupoUsuario.grupo_id == grupo_id)
        .first()
    )
    if existente:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Usuário já é membro do grupo")

    db.add(GrupoUsuario(usuario_id=body.usuario_id, grupo_id=grupo_id, is_admin=False))
    db.commit()
    grupo = db.query(Grupo).filter(Grupo.id == grupo_id).first()
    return _grupo_to_response(db, grupo)


@router.post("/{grupo_id}/admins", status_code=status.HTTP_200_OK)
def promover_admin(
    grupo_id: UUID,
    body: MembroInput,
    db: Session = Depends(get_db),
    current_user_id: str = Depends(get_current_user_id),
):
    from uuid import UUID as _UUID
    validar_usuario_admin_original(db, _UUID(current_user_id), grupo_id)

    rel = (
        db.query(GrupoUsuario)
        .filter(GrupoUsuario.usuario_id == body.usuario_id, GrupoUsuario.grupo_id == grupo_id)
        .first()
    )
    if not rel:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuário não pertence ao grupo")

    rel.is_admin = True
    db.commit()
    grupo = db.query(Grupo).filter(Grupo.id == grupo_id).first()
    return _grupo_to_response(db, grupo)