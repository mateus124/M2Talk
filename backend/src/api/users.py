from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from api.dependencies import get_current_user
from database import get_db
from repositories.user_repository import UserRepository
from schemas.user import UserSearchResponseSchema

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("/search", response_model=list[UserSearchResponseSchema])
async def search_users(
    username: str,
    current_user=Depends(get_current_user),
    db=Depends(get_db),
) -> list[UserSearchResponseSchema]:
    users = UserRepository.search_users_by_username(db, username)
    return [user for user in users if user.id != current_user.id]
