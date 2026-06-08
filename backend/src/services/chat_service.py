from __future__ import annotations

from dataclasses import dataclass
import json
from typing import Any

from fastapi import WebSocket
from sqlalchemy.orm import Session

from repositories.message_repository import MessageRepository


@dataclass(frozen=True)
class ChatParticipant:
    user_id: int
    nome: str
    email: str


class ChatService:
    def __init__(self) -> None:
        self.active_connections: dict[int, set[WebSocket]] = {}

    def register_connection(self, websocket: WebSocket, user_id: int) -> None:
        if user_id not in self.active_connections:
            self.active_connections[user_id] = set()
        self.active_connections[user_id].add(websocket)

    def unregister_connection(self, websocket: WebSocket, user_id: int) -> None:
        connections = self.active_connections.get(user_id)
        if not connections:
            return

        connections.discard(websocket)
        if not connections:
            del self.active_connections[user_id]

    def get_user_websockets(self, user_id: int) -> list[WebSocket]:
        """Retorna todos os WebSockets de um usuário"""
        return list(self.active_connections.get(user_id, set()))


    async def _send_json(self, websocket: WebSocket, payload: dict[str, Any]) -> None:
        await websocket.send_text(json.dumps(payload, ensure_ascii=False))

    async def _send_to_user(self, user_id: int, payload: dict[str, Any]) -> int:
        sent = 0
        for websocket in list(self.active_connections.get(user_id, set())):
            try:
                await self._send_json(websocket, payload)
                sent += 1
            except Exception:
                self.unregister_connection(websocket, user_id)
        return sent

    async def broadcast(self, payload: dict[str, Any]) -> int:
        sent = 0
        for user_id in list(self.active_connections.keys()):
            sent += await self._send_to_user(user_id, payload)
        return sent

    async def send_private_message(
        self,
        db: Session,
        sender: ChatParticipant,
        recipient_id: int,
        message: str,
    ) -> int:
        saved_message = MessageRepository.create_message(
            db,
            message_type="private",
            sender_id=sender.user_id,
            recipient_id=recipient_id,
            content=message,
        )

        recipient_payload = {
            "id": saved_message.id,
            "type": "private",
            "message": saved_message.content,
            "timestamp": saved_message.created_at.isoformat() if hasattr(saved_message.created_at, 'isoformat') else str(saved_message.created_at),
            "from": {
                "user_id": sender.user_id,
                "nome": sender.nome,
                "email": sender.email,
            },
            "recipient_id": recipient_id,
            "conversation_key": f"private:{min(sender.user_id, recipient_id)}:{max(sender.user_id, recipient_id)}",
            "conversation_name": sender.nome,
        }

        sender_payload = {
            **recipient_payload,
            "conversation_name": (await self._get_user_name(db, recipient_id)) or sender.nome,
        }

        delivered = await self._send_to_user(recipient_id, recipient_payload)
        delivered += await self._send_to_user(sender.user_id, sender_payload)
        return delivered

    async def send_broadcast_message(self, db: Session, sender: ChatParticipant, message: str) -> int:
        saved_message = MessageRepository.create_message(
            db,
            message_type="broadcast",
            sender_id=sender.user_id,
            content=message,
        )
        payload = {
            "id": saved_message.id,
            "type": "broadcast",
            "message": saved_message.content,
            "timestamp": saved_message.created_at.isoformat() if hasattr(saved_message.created_at, 'isoformat') else str(saved_message.created_at),
            "from": {
                "user_id": sender.user_id,
                "nome": sender.nome,
                "email": sender.email,
            },
            "conversation_key": "broadcast",
            "conversation_name": "Broadcast",
        }
        return await self.broadcast(payload)

    async def send_group_message(
        self,
        db: Session,
        sender: ChatParticipant,
        member_ids: list[int],
        group_name: str,
        message: str,
    ) -> int:
        if sender.user_id not in member_ids:
            return 0

        saved_message = MessageRepository.create_message(
            db,
            message_type="group",
            sender_id=sender.user_id,
            group_name=group_name,
            content=message,
        )
        payload = {
            "id": saved_message.id,
            "type": "group",
            "group_name": group_name,
            "conversation_key": group_name,
            "conversation_name": group_name,
            "timestamp": saved_message.created_at.isoformat() if hasattr(saved_message.created_at, 'isoformat') else str(saved_message.created_at),
            "from": {
                "user_id": sender.user_id,
                "nome": sender.nome,
                "email": sender.email,
            },
            "message": saved_message.content,
        }

        sent = 0
        for member_id in member_ids:
            sent += await self._send_to_user(member_id, payload)
        return sent

    @staticmethod
    async def _get_user_name(db: Session, user_id: int) -> str | None:
        from repositories.user_repository import UserRepository

        user = UserRepository.get_user_by_id(db, user_id)
        return user.nome if user else None


chat_service = ChatService()
