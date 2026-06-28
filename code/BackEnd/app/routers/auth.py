from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from ..database import get_db
from ..models.usuario import Usuario
from ..schemas.usuario import UsuarioRegister, UsuarioResponse, TokenResponse
from ..utils.security import get_password_hash, verify_password, create_access_token


router = APIRouter(prefix="/auth", tags=["auth"]) 


@router.post("/register", response_model=UsuarioResponse, status_code=status.HTTP_201_CREATED)
def register_user(user_data: UsuarioRegister, db: Session = Depends(get_db)):
    """
    Registra um novo usuário.

    - Verifica se o email já está cadastrado
    - Gera o hash da senha com bcrypt
    - Salva o usuário e retorna dados sem a senha
    """
    # Verificar se o email já existe
    existing = db.query(Usuario).filter(Usuario.email == user_data.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email já cadastrado"
        )

    # Criar usuário
    senha_hash = get_password_hash(user_data.senha)
    db_user = Usuario(
        nome=user_data.nome,
        email=user_data.email,
        senha_hash=senha_hash
    )

    db.add(db_user)
    db.commit()
    db.refresh(db_user)

    return UsuarioResponse(id=db_user.id, nome=db_user.nome, email=db_user.email)


@router.post("/login", response_model=TokenResponse)
def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    """
    Realiza login e retorna um token JWT (Bearer).

    - Busca usuário por email (username)
    - Verifica senha com bcrypt
    - Gera token com expiração de 60 minutos
    """
    # Buscar usuário
    user = db.query(Usuario).filter(Usuario.email == form_data.username).first()

    invalid_credentials = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Email ou senha inválidos",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if not user:
        raise invalid_credentials

    # Verificar senha
    if not verify_password(form_data.password, user.senha_hash):
        raise invalid_credentials

    # Gerar token
    access_token = create_access_token(subject=str(user.id), expires_minutes=60)

    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        user_id=user.id  # Adiciona o ID do usuário
    )