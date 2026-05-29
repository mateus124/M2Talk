from sqlalchemy.orm import Session

from models.group import GroupChat, GroupMember


class GroupRepository:
    @staticmethod
    def create_group(db: Session, nome: str, created_by_user_id: int | None) -> GroupChat:
        group = GroupChat(nome=nome, created_by_user_id=created_by_user_id)
        db.add(group)
        db.commit()
        db.refresh(group)
        return group

    @staticmethod
    def get_group_by_name(db: Session, nome: str) -> GroupChat | None:
        return db.query(GroupChat).filter(GroupChat.nome == nome).first()

    @staticmethod
    def list_groups(db: Session) -> list[GroupChat]:
        return db.query(GroupChat).order_by(GroupChat.nome.asc()).all()

    @staticmethod
    def add_member(db: Session, group_id: int, user_id: int) -> GroupMember:
        existing = (
            db.query(GroupMember)
            .filter(GroupMember.group_id == group_id, GroupMember.user_id == user_id)
            .first()
        )
        if existing:
            return existing

        member = GroupMember(group_id=group_id, user_id=user_id)
        db.add(member)
        db.commit()
        db.refresh(member)
        return member

    @staticmethod
    def remove_member(db: Session, group_id: int, user_id: int) -> bool:
        member = (
            db.query(GroupMember)
            .filter(GroupMember.group_id == group_id, GroupMember.user_id == user_id)
            .first()
        )
        if not member:
            return False

        db.delete(member)
        db.commit()
        return True

    @staticmethod
    def list_member_ids(db: Session, group_id: int) -> list[int]:
        members = db.query(GroupMember.user_id).filter(GroupMember.group_id == group_id).all()
        return [member_id for (member_id,) in members]

    @staticmethod
    def count_members(db: Session, group_id: int) -> int:
        return db.query(GroupMember).filter(GroupMember.group_id == group_id).count()

    @staticmethod
    def get_user_groups(db: Session, user_id: int) -> list[GroupChat]:
        return (
            db.query(GroupChat)
            .join(GroupMember, GroupChat.id == GroupMember.group_id)
            .filter(GroupMember.user_id == user_id)
            .all()
        )
