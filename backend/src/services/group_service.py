from sqlalchemy.orm import Session

from repositories.group_repository import GroupRepository


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

        GroupRepository.add_member(db, group.id, user_id)
        return group

    @staticmethod
    def leave_group(db: Session, group_name: str, user_id: int):
        group = GroupRepository.get_group_by_name(db, group_name)
        if not group:
            raise ValueError(f"Grupo {group_name} não encontrado")

        GroupRepository.remove_member(db, group.id, user_id)
        return group

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
