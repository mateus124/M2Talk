from sqlalchemy.orm import Session
from models.user import User


class UserRepository:
    @staticmethod
    def create_user(db: Session, nome: str, email: str, senha_hash: str) -> User:
        """Cria um novo usuário no banco de dados."""
        user = User(nome=nome, email=email, senha_hash=senha_hash)
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def get_user_by_email(db: Session, email: str) -> User | None:
        """Busca um usuário pelo email."""
        return db.query(User).filter(User.email == email).first()

    @staticmethod
    def get_user_by_username(db: Session, username: str) -> User | None:
        """Busca um usuário pelo nome de usuário."""
        return db.query(User).filter(User.nome == username).first()

    @staticmethod
    def search_users_by_username(db: Session, username: str) -> list[User]:
        """Busca usuários pelo nome de usuário, correspondência parcial."""
        pattern = f"%{username}%"
        return db.query(User).filter(User.nome.ilike(pattern)).order_by(User.nome.asc()).all()

    @staticmethod
    def get_user_by_id(db: Session, user_id: int) -> User | None:
        """Busca um usuário pelo ID."""
        return db.query(User).filter(User.id == user_id).first()
