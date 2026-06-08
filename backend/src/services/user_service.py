import bcrypt
import jwt
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from repositories.user_repository import UserRepository
from schemas.user import CreateUserSchema, LoginSchema, UserResponseSchema, TokenResponseSchema
from config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_MINUTES


class UserService:
    @staticmethod
    def hash_password(password: str) -> str:
        """Gera hash da senha usando bcrypt."""
        salt = bcrypt.gensalt(rounds=10)
        return bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")

    @staticmethod
    def verify_password(password: str, senha_hash: str) -> bool:
        """Verifica se a senha corresponde ao hash."""
        return bcrypt.checkpw(password.encode("utf-8"), senha_hash.encode("utf-8"))

    @staticmethod
    def create_access_token(user_id: int, email: str, nome: str) -> str:
        """Cria um JWT token para o usuário."""
        payload = {
            "user_id": user_id,
            "email": email,
            "nome": nome,
            "exp": datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        }
        token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
        return token

    @staticmethod
    def verify_token(token: str) -> dict | None:
        """Valida e decodifica o JWT token."""
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            return payload
        except jwt.ExpiredSignatureError:
            return None
        except jwt.InvalidTokenError:
            return None

    @staticmethod
    def register_user(db: Session, user_data: CreateUserSchema) -> UserResponseSchema:
        """
        Registra um novo usuário com validação de email único.
        
        Args:
            db: Sessão do banco de dados
            user_data: Dados de criação de usuário
            
        Returns:
            UserResponseSchema com dados do usuário criado
            
        Raises:
            ValueError: Se o email já está registrado
        """
        existing_user = UserRepository.get_user_by_email(db, user_data.email)
        if existing_user:
            raise ValueError(f"Email {user_data.email} já está registrado")

        existing_username = UserRepository.get_user_by_username(db, user_data.nome)
        if existing_username:
            raise ValueError(f"Username {user_data.nome} já está em uso")

        senha_hash = UserService.hash_password(user_data.senha)

        user = UserRepository.create_user(
            db=db,
            nome=user_data.nome,
            email=user_data.email,
            senha_hash=senha_hash
        )

        return UserResponseSchema.model_validate(user)

    @staticmethod
    def login_user(db: Session, login_data: LoginSchema) -> TokenResponseSchema:
        """
        Faz login de um usuário e retorna token JWT.
        
        Args:
            db: Sessão do banco de dados
            login_data: Email e senha do usuário
            
        Returns:
            TokenResponseSchema com access_token
            
        Raises:
            ValueError: Se credenciais inválidas
        """
        user = UserRepository.get_user_by_email(db, login_data.email)
        if not user:
            raise ValueError("Email ou senha incorretos")

        if not UserService.verify_password(login_data.senha, user.senha_hash):
            raise ValueError("Email ou senha incorretos")

        access_token = UserService.create_access_token(user.id, user.email, user.nome)

        return TokenResponseSchema(
            access_token=access_token,
            user_id=user.id,
            nome=user.nome
        )
