from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from api.dependencies import get_current_user
from database import get_db
from schemas.chat import BroadcastMessageSchema, ChatActionResponseSchema
from services.chat_service import ChatParticipant, chat_service
from repositories.message_repository import MessageRepository
from schemas.chat import ChatMessageResponseSchema


router = APIRouter(prefix="/api/chat", tags=["chat"])


@router.post("/broadcast", response_model=ChatActionResponseSchema)
async def send_broadcast(
    payload: BroadcastMessageSchema,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ChatActionResponseSchema:
    participant = ChatParticipant(user_id=current_user.id, nome=current_user.nome, email=current_user.email)
    delivered = await chat_service.send_broadcast_message(db, participant, payload.message)
    return ChatActionResponseSchema(
        detail="Broadcast enviado",
        member_count=delivered,
    )


@router.get("/history", response_model=list[ChatMessageResponseSchema])
async def get_history(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    return MessageRepository.get_user_history(db, current_user.id)
