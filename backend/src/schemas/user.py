from pydantic import BaseModel, EmailStr, Field
from datetime import datetime


class CreateUserSchema(BaseModel):
    nome: str = Field(..., min_length=3, max_length=255, description="Nome do usuário")
    email: EmailStr = Field(..., description="Email único do usuário")
    senha: str = Field(..., min_length=6, description="Senha (mínimo 6 caracteres)")


class UserResponseSchema(BaseModel):
    id: int
    nome: str
    email: str
    created_at: datetime

    class Config:
        from_attributes = True


class UserSearchResponseSchema(BaseModel):
    id: int
    nome: str

    class Config:
        from_attributes = True


class LoginSchema(BaseModel):
    email: EmailStr = Field(..., description="Email do usuário")
    senha: str = Field(..., description="Senha do usuário")


class TokenResponseSchema(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    nome: str

