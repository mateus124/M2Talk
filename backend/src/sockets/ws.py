import json
from database import SessionLocal
from fastapi import WebSocket, WebSocketDisconnect, status
from typing import List, Dict

from services.chat_service import ChatParticipant, chat_service
from services.group_service import GroupService
from services.user_service import UserService


async def send_event(websocket: WebSocket, payload: dict) -> None:
    await websocket.send_text(json.dumps(payload, ensure_ascii=False))


async def notify_user(user_id: int, payload: dict) -> int:
    sent = 0
    for websocket in chat_service.get_user_websockets(user_id):
        try:
            await websocket.send_text(json.dumps(payload, ensure_ascii=False))
            sent += 1
        except Exception:
            chat_service.unregister_connection(websocket, user_id)
    return sent


async def notify_users(user_ids: list[int], payload: dict) -> int:
    sent = 0
    for user_id in user_ids:
        sent += await notify_user(user_id, payload)
    return sent


class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, group_name: str, websocket: WebSocket):
        """Conecta um WebSocket a um grupo. Usa durante handshake inicial."""
        await websocket.accept()
        self._add_connection(group_name, websocket)

    def _add_connection(self, group_name: str, websocket: WebSocket):
        """Adiciona WebSocket já aceito a um grupo (sem chamar accept novamente)."""
        if group_name not in self.active_connections:
            self.active_connections[group_name] = []
        if websocket not in self.active_connections[group_name]:
            self.active_connections[group_name].append(websocket)
        print(f"WebSocket adicionado ao grupo '{group_name}'. Total no grupo: {len(self.active_connections[group_name])}")

    def disconnect(self, group_name: str, websocket: WebSocket):
        if group_name in self.active_connections:
            try:
                self.active_connections[group_name].remove(websocket)
                print(f"WebSocket removido do grupo '{group_name}'. Total no grupo: {len(self.active_connections[group_name])}")
            except ValueError:
                pass

    async def _ensure_group_websockets(self, group_name: str, member_ids: list[int], db):
        """
        Garante que todos os WebSockets dos membros do grupo estejam registrados.
        Registra dinamicamente qualquer WebSocket ativo de membro que ainda não esteja registrado.
        """
        # Obter WebSockets já registrados no grupo
        existing_websockets = self.active_connections.get(group_name, [])
        existing_user_ids = set()
        
        # Criar mapping de user_id para websocket usando chat_service
        for user_id in member_ids:
            user_websockets = chat_service.get_user_websockets(user_id)
            for ws in user_websockets:
                if ws not in existing_websockets:
                    self._add_connection(group_name, ws)
                    print(f"✓ WebSocket do usuário {user_id} adicionado dinamicamente ao grupo '{group_name}'")

    async def broadcast_to_group(self, group_name: str, message: dict, member_ids: list[int] = None, db=None):
        """
        Envia mensagem para todos os WebSockets registrados no grupo.
        Se member_ids for fornecido, registra dinamicamente WebSockets de membros que ainda não estão registrados.
        """
        # Se temos IDs de membros, garantir que todos estejam registrados
        if member_ids and db:
            await self._ensure_group_websockets(group_name, member_ids, db)
        
        if group_name in self.active_connections:
            print(f"Enviando mensagem para {len(self.active_connections[group_name])} WebSockets no grupo '{group_name}'")
            for connection in self.active_connections[group_name]:
                try:
                    await connection.send_json(message)
                except Exception as e:
                    print(f"Erro ao enviar mensagem ao WebSocket: {e}")
        else:
            print(f"Nenhum WebSocket registrado para o grupo '{group_name}'. Grupos disponíveis: {list(self.active_connections.keys())}")

manager = ConnectionManager()


async def send_system_message(websocket: WebSocket, message: str) -> None:
    await websocket.send_text(json.dumps({"type": "system", "message": message}, ensure_ascii=False))


async def websocket_endpoint(websocket: WebSocket, token: str | None = None):
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Token não fornecido")
        return

    payload = UserService.verify_token(token)
    if not payload:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Token inválido ou expirado")
        return

    user_id = payload.get("user_id")
    email = payload.get("email")
    nome = payload.get("nome") or email.split("@")[0]
    db = SessionLocal()

    await websocket.accept()
    chat_service.register_connection(websocket, user_id)
    
    # Registrar o WebSocket nos grupos que o usuário é membro
    try:
        user_groups = GroupService.get_user_groups(db, user_id)
        for group in user_groups:
            manager._add_connection(group.nome, websocket)
    except Exception as e:
        print(f"Erro ao registrar usuário nos grupos: {e}")
    
    try:
        while True:
            data = await websocket.receive_text()
            participant = ChatParticipant(user_id=user_id, nome=nome, email=email)

            try:
                content = json.loads(data)
            except json.JSONDecodeError:
                delivered = await chat_service.send_broadcast_message(participant, data)
                await send_system_message(websocket, f"Broadcast enviado para {delivered} conexões")
                continue

            action = content.get("action")
            message = content.get("message") or ""
            group_name = content.get("group_name") or ""
            recipient_id = content.get("recipient_id")

            if action == "broadcast":
                delivered = await chat_service.send_broadcast_message(db, participant, message)
                await send_system_message(websocket, f"Broadcast enviado para {delivered} conexões")
            elif action == "private_message":
                if recipient_id is None:
                    await send_system_message(websocket, "recipient_id é obrigatório")
                    continue
                delivered = await chat_service.send_private_message(db, participant, int(recipient_id), message)
                await send_system_message(websocket, f"Mensagem privada entregue para {delivered} conexão(ões)")
            elif action == "join_group":
                try:
                    GroupService.join_group(db, group_name, user_id)
                    manager._add_connection(group_name, websocket)
                    member_count = GroupService.group_member_count(db, group_name)
                    await send_system_message(websocket, f"Entrou no grupo {group_name}. Membros: {member_count}")
                except ValueError as exc:
                    await send_system_message(websocket, str(exc))
            elif action == "leave_group":
                try:
                    GroupService.leave_group(db, group_name, user_id)
                    manager.disconnect(group_name, websocket)
                    await send_event(websocket, {"type": "group_left", "group_name": group_name})
                    try:
                        member_count = GroupService.group_member_count(db, group_name)
                    except ValueError:
                        member_count = 0
                    await send_system_message(websocket, f"Saiu do grupo {group_name}. Membros: {member_count}")
                except ValueError as exc:
                    await send_system_message(websocket, str(exc))
            elif action == "invite_user":
                username = content.get("username") or ""
                try:
                    invited_user = GroupService.add_member_to_group(db, group_name, username, user_id)
                    invited_websockets = chat_service.get_user_websockets(invited_user.id)
                    for invited_ws in invited_websockets:
                        manager._add_connection(group_name, invited_ws)
                        await send_event(invited_ws, {"type": "group_joined", "group_name": group_name})
                    await send_system_message(websocket, f"Usuário {username} adicionado ao grupo {group_name}")
                except ValueError as exc:
                    await send_system_message(websocket, str(exc))
            elif action == "group_message":
                try:
                    member_ids = GroupService.group_member_ids(db, group_name)
                    delivered = await chat_service.send_group_message(db, participant, member_ids, group_name, message)
                    if delivered == 0:
                        await send_system_message(websocket, f"Você precisa entrar no grupo {group_name} antes de enviar mensagem")
                    else:
                        await send_system_message(websocket, f"Mensagem enviada para o grupo {group_name}")
                except ValueError as exc:
                    await send_system_message(websocket, str(exc))
            elif action == "list_groups":
                groups = GroupService.get_user_groups(db, user_id)
                await send_event(websocket, {"type": "groups", "groups": [{"id": group.id, "nome": group.nome, "created_by_user_id": group.created_by_user_id} for group in groups]})
            elif action == "group_member_count":
                try:
                    member_count = GroupService.group_member_count(db, group_name)
                    await send_event(websocket, {"type": "group_member_count", "group_name": group_name, "member_count": member_count})
                except ValueError as exc:
                    await send_system_message(websocket, str(exc))
            elif action == "create_group":
                try:
                    created_group = GroupService.create_group(db, group_name, user_id)
                    await send_event(websocket, {
                        "type": "group_created",
                        "group_name": created_group.nome,
                        "created_by_user_id": created_group.created_by_user_id,
                    })
                except ValueError as exc:
                    await send_system_message(websocket, str(exc))
            elif action == "delete_group":
                try:
                    deleted_group, member_ids = GroupService.delete_group(db, group_name, user_id)
                    await notify_users(member_ids, {"type": "group_deleted", "group_name": group_name})
                    await send_system_message(websocket, f"Grupo {group_name} excluído com sucesso")
                except ValueError as exc:
                    await send_system_message(websocket, str(exc))
            else:
                await send_system_message(websocket, "Ação desconhecida")

    except WebSocketDisconnect:
        chat_service.unregister_connection(websocket, user_id)
        # Desregistrar do WebSocket de todos os grupos
        try:
            user_groups = GroupService.get_user_groups(db, user_id)
            for group in user_groups:
                manager.disconnect(group.nome, websocket)
        except Exception as e:
            print(f"Erro ao desregistrar usuário dos grupos: {e}")
    except Exception as e:
        print(f"Erro no WebSocket: {e}")
        chat_service.unregister_connection(websocket, user_id)
        # Desregistrar do WebSocket de todos os grupos
        try:
            user_groups = GroupService.get_user_groups(db, user_id)
            for group in user_groups:
                manager.disconnect(group.nome, websocket)
        except Exception as e:
            print(f"Erro ao desregistrar usuário dos grupos: {e}")
    finally:
        db.close()