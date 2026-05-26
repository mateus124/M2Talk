from __future__ import annotations

from dataclasses import dataclass
import json
from typing import Any

from fastapi import WebSocket


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

    async def send_private_message(self, sender: ChatParticipant, recipient_id: int, message: str) -> int:
        payload = {
            "type": "private_message",
            "from": {
                "user_id": sender.user_id,
                "nome": sender.nome,
                "email": sender.email,
            },
            "message": message,
        }
        return await self._send_to_user(recipient_id, payload)

    async def send_broadcast_message(self, sender: ChatParticipant, message: str) -> int:
        payload = {
            "type": "broadcast",
            "from": {
                "user_id": sender.user_id,
                "nome": sender.nome,
                "email": sender.email,
            },
            "message": message,
        }
        return await self.broadcast(payload)

    async def send_group_message(self, sender: ChatParticipant, member_ids: list[int], group_name: str, message: str) -> int:
        if sender.user_id not in member_ids:
            return 0

        payload = {
            "type": "group_message",
            "group_name": group_name,
            "from": {
                "user_id": sender.user_id,
                "nome": sender.nome,
                "email": sender.email,
            },
            "message": message,
        }

        sent = 0
        for member_id in member_ids:
            sent += await self._send_to_user(member_id, payload)
        return sent


chat_service = ChatService()
