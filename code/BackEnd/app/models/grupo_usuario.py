from sqlalchemy import Column, ForeignKey, PrimaryKeyConstraint, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from ..database import Base

class GrupoUsuario(Base):
    __tablename__ = "grupo_usuarios"
    
    usuario_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    grupo_id = Column(UUID(as_uuid=True), ForeignKey("grupos.id", ondelete="CASCADE"), nullable=False)
    is_admin = Column(Boolean, nullable=False, default=False)
    
    # Definindo chave primária composta
    __table_args__ = (
        PrimaryKeyConstraint('usuario_id', 'grupo_id'),
    )
    
    # Relacionamentos
    usuario = relationship("Usuario", back_populates="grupos")
    grupo = relationship("Grupo", back_populates="usuarios")
    
    def __repr__(self):
        return f"<GrupoUsuario(usuario_id={self.usuario_id}, grupo_id={self.grupo_id})>"
