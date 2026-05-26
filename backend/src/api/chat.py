from fastapi import APIRouter, Depends

from api.dependencies import get_current_user
from schemas.chat import BroadcastMessageSchema, ChatActionResponseSchema
from services.chat_service import ChatParticipant, chat_service


router = APIRouter(prefix="/api/chat", tags=["chat"])


@router.post("/broadcast", response_model=ChatActionResponseSchema)
async def send_broadcast(
    payload: BroadcastMessageSchema,
    current_user=Depends(get_current_user),
) -> ChatActionResponseSchema:
    participant = ChatParticipant(user_id=current_user.id, nome=current_user.nome, email=current_user.email)
    delivered = await chat_service.send_broadcast_message(participant, payload.message)
    return ChatActionResponseSchema(
        detail="Broadcast enviado",
        member_count=delivered,
    )
