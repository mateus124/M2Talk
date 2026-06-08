from fastapi import APIRouter, Depends, HTTPException, status

from api.dependencies import get_current_user
from database import get_db
from schemas.group import (
    CreateGroupSchema,
    GroupActionResponseSchema,
    GroupListResponseSchema,
    GroupMembersResponseSchema,
)
from schemas.chat import GroupMessageSchema
from services.chat_service import ChatParticipant, chat_service
from services.group_service import GroupService
from sockets.ws import manager


router = APIRouter(prefix="/api/groups", tags=["groups"])


@router.post("", response_model=GroupActionResponseSchema, status_code=status.HTTP_201_CREATED)
async def create_group(
    payload: CreateGroupSchema,
    current_user=Depends(get_current_user),
    db=Depends(get_db),
) -> GroupActionResponseSchema:
    try:
        group = GroupService.create_group(db, payload.nome, current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))

    member_count = GroupService.group_member_count(db, group.nome)

    # Registrar o WebSocket do usuário no novo grupo (sem chamar accept novamente)
    user_websockets = chat_service.get_user_websockets(current_user.id)
    for websocket in user_websockets:
        try:
            manager._add_connection(group.nome, websocket)
        except Exception as e:
            print(f"Erro ao registrar WebSocket no grupo: {e}")

    return GroupActionResponseSchema(
        detail="Grupo criado com sucesso",
        group_name=group.nome,
        member_count=member_count,
    )


@router.get("", response_model=GroupListResponseSchema)
async def list_groups(db=Depends(get_db)) -> GroupListResponseSchema:
    groups = GroupService.list_groups(db)
    return GroupListResponseSchema(groups=groups)


@router.post("/{group_name}/join", response_model=GroupActionResponseSchema)
async def join_group(
    group_name: str,
    current_user=Depends(get_current_user),
    db=Depends(get_db),
) -> GroupActionResponseSchema:
    try:
        GroupService.join_group(db, group_name, current_user.id)
        member_count = GroupService.group_member_count(db, group_name)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))

    # Registrar o WebSocket do usuário no grupo (sem chamar accept novamente)
    user_websockets = chat_service.get_user_websockets(current_user.id)
    for websocket in user_websockets:
        try:
            manager._add_connection(group_name, websocket)
        except Exception as e:
            print(f"Erro ao registrar WebSocket no grupo: {e}")

    return GroupActionResponseSchema(
        detail="Usuário entrou no grupo",
        group_name=group_name,
        member_count=member_count,
    )


@router.post("/{group_name}/leave", response_model=GroupActionResponseSchema)
async def leave_group(
    group_name: str,
    current_user=Depends(get_current_user),
    db=Depends(get_db),
) -> GroupActionResponseSchema:
    try:
        GroupService.leave_group(db, group_name, current_user.id)
        member_count = GroupService.group_member_count(db, group_name)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))

    return GroupActionResponseSchema(
        detail="Usuário saiu do grupo",
        group_name=group_name,
        member_count=member_count,
    )


@router.get("/{group_name}/members/count", response_model=GroupActionResponseSchema)
async def group_member_count(group_name: str, db=Depends(get_db)) -> GroupActionResponseSchema:
    try:
        member_count = GroupService.group_member_count(db, group_name)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))

    return GroupActionResponseSchema(
        detail="Quantidade de membros consultada",
        group_name=group_name,
        member_count=member_count,
    )


@router.get("/{group_name}/members", response_model=GroupMembersResponseSchema)
async def group_members(group_name: str, db=Depends(get_db)) -> GroupMembersResponseSchema:
    try:
        member_ids = GroupService.group_member_ids(db, group_name)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))

    return GroupMembersResponseSchema(
        group_name=group_name,
        member_ids=member_ids,
        member_count=len(member_ids),
    )


@router.post("/{group_name}/message", response_model=GroupActionResponseSchema)
async def send_group_message(
    group_name: str,
    message_input: GroupMessageSchema,
    current_user=Depends(get_current_user),
    db=Depends(get_db),
) -> GroupActionResponseSchema:
    try:
        member_ids = GroupService.group_member_ids(db, group_name)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))

    participant = ChatParticipant(user_id=current_user.id, nome=current_user.nome, email=current_user.email)
    if participant.user_id not in member_ids:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuário precisa entrar no grupo antes de enviar mensagem",
        )

    delivered = await chat_service.send_group_message(db, participant, member_ids, group_name, message_input.message)

    return GroupActionResponseSchema(
        detail="Mensagem de grupo enviada",
        group_name=group_name,
        member_count=delivered,
    )
