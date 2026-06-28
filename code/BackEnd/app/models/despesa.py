from sqlalchemy import Column, String, Numeric, Date, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..database import Base
import uuid

class Despesa(Base):
    __tablename__ = "despesas"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    titulo = Column(String, nullable=False)
    descricao = Column(String, nullable=True)
    valor_total = Column(Numeric(10, 2), nullable=False)
    data = Column(Date, nullable=False)
    pagador_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"), nullable=False)
    grupo_id = Column(UUID(as_uuid=True), ForeignKey("grupos.id"), nullable=True)
    data_criacao = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relacionamentos
    pagador = relationship("Usuario", foreign_keys=[pagador_id])
    grupo = relationship("Grupo")
    divisoes = relationship("DivisaoDespesa", back_populates="despesa", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Despesa(id={self.id}, titulo='{self.titulo}', valor_total={self.valor_total})>"
