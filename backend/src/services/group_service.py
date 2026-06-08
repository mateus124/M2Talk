from sqlalchemy.orm import Session

from repositories.group_repository import GroupRepository
from repositories.user_repository import UserRepository


DEFAULT_GROUPS = ("geral", "turma", "projeto")


class GroupService:
    @staticmethod
    def ensure_default_groups(db: Session) -> None:
        for group_name in DEFAULT_GROUPS:
            if not GroupRepository.get_group_by_name(db, group_name):
                GroupRepository.create_group(db, group_name, created_by_user_id=None)

    @staticmethod
    def create_group(db: Session, nome: str, created_by_user_id: int):
        existing = GroupRepository.get_group_by_name(db, nome)
        if existing:
            raise ValueError(f"Grupo {nome} já existe")

        group = GroupRepository.create_group(db, nome, created_by_user_id)
        GroupRepository.add_member(db, group.id, created_by_user_id)
        return group

    @staticmethod
    def list_groups(db: Session):
        return GroupRepository.list_groups(db)

    @staticmethod
    def join_group(db: Session, group_name: str, user_id: int):
        group = GroupRepository.get_group_by_name(db, group_name)
        if not group:
            raise ValueError(f"Grupo {group_name} não encontrado")

        if GroupRepository.is_member(db, group.id, user_id):
            return group

        raise ValueError("Usuário não pode entrar no grupo sem convite")

    @staticmethod
    def leave_group(db: Session, group_name: str, user_id: int):
        group = GroupRepository.get_group_by_name(db, group_name)
        if not group:
            raise ValueError(f"Grupo {group_name} não encontrado")

        if not GroupRepository.is_member(db, group.id, user_id):
            raise ValueError("Usuário não faz parte do grupo")

        GroupRepository.remove_member(db, group.id, user_id)

        if GroupRepository.count_members(db, group.id) == 0:
            GroupRepository.delete_group(db, group.id)

        return group

    @staticmethod
    def add_member_to_group(db: Session, group_name: str, username: str, inviter_id: int):
        group = GroupRepository.get_group_by_name(db, group_name)
        if not group:
            raise ValueError(f"Grupo {group_name} não encontrado")

        if not GroupRepository.is_member(db, group.id, inviter_id):
            raise ValueError("Usuário precisa ser membro do grupo para adicionar outros usuários")

        user = UserRepository.get_user_by_username(db, username)
        if not user:
            raise ValueError(f"Usuário {username} não encontrado")

        if GroupRepository.is_member(db, group.id, user.id):
            raise ValueError(f"Usuário {username} já é membro do grupo")

        GroupRepository.add_member(db, group.id, user.id)
        return user

    @staticmethod
    def delete_group(db: Session, group_name: str, user_id: int):
        group = GroupRepository.get_group_by_name(db, group_name)
        if not group:
            raise ValueError(f"Grupo {group_name} não encontrado")

        if group.created_by_user_id != user_id:
            raise ValueError("Apenas o criador do grupo pode excluir o grupo")

        member_ids = GroupRepository.delete_group(db, group.id)
        return group, member_ids

    @staticmethod
    def group_member_ids(db: Session, group_name: str) -> list[int]:
        group = GroupRepository.get_group_by_name(db, group_name)
        if not group:
            raise ValueError(f"Grupo {group_name} não encontrado")

        return GroupRepository.list_member_ids(db, group.id)

    @staticmethod
    def group_member_count(db: Session, group_name: str) -> int:
        group = GroupRepository.get_group_by_name(db, group_name)
        if not group:
            raise ValueError(f"Grupo {group_name} não encontrado")

        return GroupRepository.count_members(db, group.id)

    @staticmethod
    def get_user_groups(db: Session, user_id: int):
        return GroupRepository.get_user_groups(db, user_id)
