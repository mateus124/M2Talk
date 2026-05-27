from pydantic import BaseModel, Field
from datetime import datetime


class PrivateMessageSchema(BaseModel):
    recipient_id: int = Field(..., description="ID do usuário que vai receber a mensagem")
    message: str = Field(..., min_length=1, max_length=2000, description="Conteúdo da mensagem")


class BroadcastMessageSchema(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000, description="Mensagem para todos os usuários conectados")


class GroupMessageSchema(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000, description="Conteúdo da mensagem")


class ChatMessageResponseSchema(BaseModel):
    id: int
    type: str
    message: str
    timestamp: datetime
    from_: dict = Field(..., alias="from")
    recipient_id: int | None = None
    group_name: str | None = None
    conversation_key: str
    conversation_name: str

    class Config:
        populate_by_name = True


class ChatActionResponseSchema(BaseModel):
    detail: str
    group_name: str | None = None
    member_count: int | None = None
