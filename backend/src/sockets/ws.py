import json
from database import SessionLocal
from fastapi import WebSocket, WebSocketDisconnect, status

from services.chat_service import ChatParticipant, chat_service
from services.group_service import GroupService
from services.user_service import UserService


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
                    member_count = GroupService.group_member_count(db, group_name)
                    await send_system_message(websocket, f"Entrou no grupo {group_name}. Membros: {member_count}")
                except ValueError as exc:
                    await send_system_message(websocket, str(exc))
            elif action == "leave_group":
                try:
                    GroupService.leave_group(db, group_name, user_id)
                    member_count = GroupService.group_member_count(db, group_name)
                    await send_system_message(websocket, f"Saiu do grupo {group_name}. Membros: {member_count}")
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
                groups = GroupService.list_groups(db)
                await websocket.send_text(json.dumps({"type": "groups", "groups": [{"id": group.id, "nome": group.nome, "created_by_user_id": group.created_by_user_id} for group in groups]}, ensure_ascii=False))
            elif action == "group_member_count":
                try:
                    member_count = GroupService.group_member_count(db, group_name)
                    await websocket.send_text(json.dumps({"type": "group_member_count", "group_name": group_name, "member_count": member_count}, ensure_ascii=False))
                except ValueError as exc:
                    await send_system_message(websocket, str(exc))
            elif action == "create_group":
                try:
                    created_group = GroupService.create_group(db, group_name, user_id)
                    await websocket.send_text(json.dumps({"type": "group_created", "group_name": created_group.nome}, ensure_ascii=False))
                except ValueError as exc:
                    await send_system_message(websocket, str(exc))
            else:
                await send_system_message(websocket, "Ação desconhecida")

    except WebSocketDisconnect:
        chat_service.unregister_connection(websocket, user_id)
    except Exception as e:
        print(f"Erro no WebSocket: {e}")
        chat_service.unregister_connection(websocket, user_id)
    finally:
        db.close()