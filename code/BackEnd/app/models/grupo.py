from sqlalchemy import Column, String, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from ..database import Base
import uuid

class Grupo(Base):
    __tablename__ = "grupos"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nome = Column(String, nullable=False)
    administrador_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"), nullable=False)
    
    # Relacionamentos
    usuarios = relationship("GrupoUsuario", back_populates="grupo")
    despesas = relationship("Despesa", back_populates="grupo")
    
    def __repr__(self):
        return f"<Grupo(id={self.id}, nome='{self.nome}')>"
