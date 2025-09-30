from fastapi import APIRouter, Depends
from ..auth import get_current_user
from pydantic import BaseModel
import httpx

router = APIRouter(tags=["Predictions"])

class PredictionRequest(BaseModel):
    entity_id: str
    entity_type: str

@router.post("/predictions/stock-out")
async def predict_stock_out(request: PredictionRequest, current_user: dict = Depends(get_current_user)):
    async with httpx.AsyncClient() as client:
        # Forward to prediction-service (to be implemented)
        response = await client.post(
            "http://prediction-service:8001/predict/stock-out",
            json={"entity_id": request.entity_id, "entity_type": request.entity_type}
        )
        return response.json()
    