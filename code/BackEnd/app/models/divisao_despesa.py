from sqlalchemy import Column, Numeric, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from ..database import Base
import uuid

class DivisaoDespesa(Base):
    __tablename__ = "divisao_despesas"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    despesa_id = Column(UUID(as_uuid=True), ForeignKey("despesas.id", ondelete="CASCADE"), nullable=False)
    usuario_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"), nullable=False)
    valor_devido = Column(Numeric(10, 2), nullable=False)
    
    # Relacionamentos
    despesa = relationship("Despesa", back_populates="divisoes")
    usuario = relationship("Usuario", back_populates="divisoes")
    
    def __repr__(self):
        return f"<DivisaoDespesa(despesa_id={self.despesa_id}, usuario_id={self.usuario_id}, valor_devido={self.valor_devido})>"
