from fastapi import APIRouter, Depends
from ..auth import get_current_user

router = APIRouter(tags=["Health"])

@router.get("/health")
async def health_check(current_user: dict = Depends(get_current_user)):
    return {"status": "healthy", "user": current_user["user_id"]}