from fastapi import APIRouter

from .auth import router as auth_router
from .chat import router as chat_router
from .groups import router as groups_router
from .private_chat import router as private_chat_router


router = APIRouter()
router.include_router(auth_router)
router.include_router(chat_router)
router.include_router(private_chat_router)
router.include_router(groups_router)

__all__ = ["router"]
