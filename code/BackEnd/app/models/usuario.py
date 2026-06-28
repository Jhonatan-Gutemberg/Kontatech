from sqlalchemy import Column, String, Numeric
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from ..database import Base
import uuid

class Usuario(Base):
    __tablename__ = "usuarios"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nome = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False, index=True)
    senha_hash = Column(String, nullable=False)
    renda_mensal = Column(Numeric(10, 2), nullable=True)
    
    # Relacionamentos
    grupos = relationship("GrupoUsuario", back_populates="usuario")
    despesas_pagas = relationship("Despesa", foreign_keys="Despesa.pagador_id")
    divisoes = relationship("DivisaoDespesa", back_populates="usuario")
    
    def __repr__(self):
        return f"<Usuario(id={self.id}, nome='{self.nome}', email='{self.email}')>"
