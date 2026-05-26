from pydantic import BaseModel, Field


class CreateGroupSchema(BaseModel):
    nome: str = Field(..., min_length=3, max_length=255, description="Nome do grupo")


class GroupResponseSchema(BaseModel):
    id: int
    nome: str
    created_by_user_id: int

    class Config:
        from_attributes = True


class GroupListResponseSchema(BaseModel):
    groups: list[GroupResponseSchema]


class GroupMembersResponseSchema(BaseModel):
    group_name: str
    member_ids: list[int]
    member_count: int


class GroupActionResponseSchema(BaseModel):
    detail: str
    group_name: str | None = None
    member_count: int | None = None
