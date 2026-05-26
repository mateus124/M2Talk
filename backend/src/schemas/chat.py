from pydantic import BaseModel, Field


class PrivateMessageSchema(BaseModel):
    recipient_id: int = Field(..., description="ID do usuário que vai receber a mensagem")
    message: str = Field(..., min_length=1, max_length=2000, description="Conteúdo da mensagem")


class BroadcastMessageSchema(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000, description="Mensagem para todos os usuários conectados")


class GroupMessageSchema(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000, description="Conteúdo da mensagem")


class ChatActionResponseSchema(BaseModel):
    detail: str
    group_name: str | None = None
    member_count: int | None = None
