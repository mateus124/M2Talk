from fastapi import APIRouter, Depends, HTTPException, status

from api.dependencies import get_current_user
from schemas.chat import ChatActionResponseSchema, PrivateMessageSchema
from services.chat_service import ChatParticipant, chat_service


router = APIRouter(prefix="/api/private-chat", tags=["private-chat"])


@router.post("/message", response_model=ChatActionResponseSchema)
async def send_private_message(
    payload: PrivateMessageSchema,
    current_user=Depends(get_current_user),
) -> ChatActionResponseSchema:
    participant = ChatParticipant(user_id=current_user.id, nome=current_user.nome, email=current_user.email)
    delivered = await chat_service.send_private_message(participant, payload.recipient_id, payload.message)
    if delivered == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuário destinatário não está conectado",
        )

    return ChatActionResponseSchema(
        detail="Mensagem privada enviada",
        member_count=delivered,
    )
