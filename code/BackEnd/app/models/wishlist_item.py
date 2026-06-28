from sqlalchemy import Column, String, Numeric, DateTime, Boolean, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..database import Base
import uuid


class WishlistItem(Base):
    __tablename__ = "wishlist_itens"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    grupo_id = Column(UUID(as_uuid=True), ForeignKey("grupos.id"), nullable=False)
    symbol = Column(String, nullable=False)  # Ex.: "AAPL", "TSLA", "PETR4.SA"
    provider = Column(String, nullable=False, default="FINNHUB")
    titulo = Column(String, nullable=True)
    preco_alvo = Column(Numeric(10, 2), nullable=False)
    preco_atual = Column(Numeric(10, 2), nullable=True)
    atingido = Column(Boolean, nullable=False, default=False)
    expirado = Column(Boolean, nullable=False, default=False)  # Prazo expirou sem atingir o alvo
    data_criacao = Column(DateTime(timezone=True), server_default=func.now())
    data_limite = Column(DateTime(timezone=True), nullable=True)  # Data limite para monitoramento

    grupo = relationship("Grupo")

    def __repr__(self):
        return (
            f"<WishlistItem(id={self.id}, symbol='{self.symbol}', "
            f"preco_alvo={self.preco_alvo}, grupo_id={self.grupo_id}, "
            f"atingido={self.atingido}, expirado={self.expirado})>"
        )