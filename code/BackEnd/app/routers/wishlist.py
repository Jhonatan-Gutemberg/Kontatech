from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID as UUID_t

from ..database import get_db
from ..utils.auth import get_current_user_id
from ..utils.validators import (
    validar_grupo_existe,
    validar_usuario_pertence_grupo,
)
from ..models.wishlist_item import WishlistItem
from ..schemas.wishlist import WishlistCreate, WishlistResponse


router = APIRouter(prefix="/wishlist", tags=["wishlist"])


@router.post("/", response_model=WishlistResponse, status_code=status.HTTP_201_CREATED)
def criar_item_wishlist(
    payload: WishlistCreate,
    current_user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    grupo = validar_grupo_existe(db, payload.grupo_id)
    # current_user_id é str; converter para UUID para validação
    validar_usuario_pertence_grupo(db, UUID_t(current_user_id), grupo.id)

    item = WishlistItem(
        grupo_id=payload.grupo_id,
        symbol=payload.symbol,
        provider="FINNHUB",
        titulo=payload.titulo,
        preco_alvo=payload.preco_alvo,
        preco_atual=None,
        atingido=False,
        expirado=False,
        data_limite=payload.data_limite,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.get("/grupo/{grupo_id}", response_model=List[WishlistResponse])
def listar_wishlist_por_grupo(
    grupo_id: UUID_t,
    current_user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    validar_grupo_existe(db, grupo_id)
    validar_usuario_pertence_grupo(db, UUID_t(current_user_id), grupo_id)

    itens = db.query(WishlistItem).filter(WishlistItem.grupo_id == grupo_id).all()
    return itens


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def deletar_item_wishlist(
    item_id: UUID_t,
    current_user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    item = db.query(WishlistItem).filter(WishlistItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item de wishlist não encontrado")

    # Permitir exclusão por qualquer membro do grupo do item
    validar_usuario_pertence_grupo(db, UUID_t(current_user_id), item.grupo_id)

    db.delete(item)
    db.commit()
    return None