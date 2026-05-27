from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from models.group import GroupMember, GroupChat
from models.message import ChatMessage
from models.user import User


class MessageRepository:
    @staticmethod
    def create_message(
        db: Session,
        *,
        message_type: str,
        sender_id: int,
        content: str,
        recipient_id: int | None = None,
        group_name: str | None = None,
    ) -> ChatMessage:
        message = ChatMessage(
            message_type=message_type,
            sender_id=sender_id,
            recipient_id=recipient_id,
            group_name=group_name,
            content=content,
        )
        db.add(message)
        db.commit()
        db.refresh(message)
        return message

    @staticmethod
    def get_user_history(db: Session, user_id: int) -> list[dict]:
        group_names = [
            group_name
            for (group_name,) in (
                db.query(GroupChat.nome)
                .join(GroupMember, GroupMember.group_id == GroupChat.id)
                .filter(GroupMember.user_id == user_id)
                .all()
            )
        ]

        conditions = [
            ChatMessage.message_type == "broadcast",
            and_(
                ChatMessage.message_type == "private",
                or_(ChatMessage.sender_id == user_id, ChatMessage.recipient_id == user_id),
            ),
            and_(ChatMessage.message_type == "group", ChatMessage.sender_id == user_id),
        ]

        if group_names:
            conditions.append(
                and_(
                    ChatMessage.message_type == "group",
                    ChatMessage.group_name.in_(group_names),
                )
            )

        messages = (
            db.query(ChatMessage, User.nome, User.email)
            .join(User, User.id == ChatMessage.sender_id)
            .filter(or_(*conditions))
            .order_by(ChatMessage.created_at.asc(), ChatMessage.id.asc())
            .all()
        )

        history: list[dict] = []
        for message, sender_name, sender_email in messages:
            if message.message_type == "private":
                other_user_id = message.recipient_id if message.sender_id == user_id else message.sender_id
                other_user = db.query(User).filter(User.id == other_user_id).first() if other_user_id else None
                conversation_key = f"private:{min(message.sender_id, message.recipient_id or message.sender_id)}:{max(message.sender_id, message.recipient_id or message.sender_id)}"
                conversation_name = other_user.nome if other_user else sender_name
            elif message.message_type == "group":
                conversation_key = message.group_name or "group"
                conversation_name = message.group_name or "Grupo"
            else:
                conversation_key = "broadcast"
                conversation_name = "Broadcast"

            history.append(
                {
                    "id": message.id,
                    "type": message.message_type,
                    "message": message.content,
                    "timestamp": message.created_at,
                    "from": {
                        "user_id": message.sender_id,
                        "nome": sender_name,
                        "email": sender_email,
                    },
                    "recipient_id": message.recipient_id,
                    "group_name": message.group_name,
                    "conversation_key": conversation_key,
                    "conversation_name": conversation_name,
                }
            )

        return history
