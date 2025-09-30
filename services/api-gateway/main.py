from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator
from jose import JWTError, jwt
from pydantic import BaseModel
from typing import Optional
import os
from dotenv import load_dotenv
from auth import verify_token
from routes import health, predictions

load_dotenv()

app = FastAPI(
    title="Aurora API Gateway",
    description="API Gateway for Aurora System of Intelligence",
    version=os.getenv("API_VERSION", "v1alpha1")
)

# Enable Prometheus metrics
Instrumentator().instrument(app).expose(app, endpoint="/metrics")

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # Update for UI
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# OAuth2 scheme for JWT
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/token")

# Include routers
app.include_router(health.router, prefix=f"/api/{os.getenv('API_VERSION', 'v1alpha1')}")
app.include_router(predictions.router, prefix=f"/api/{os.getenv('API_VERSION', 'v1alpha1')}")

# Dependency for protected routes
async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = verify_token(token)
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
        return {"user_id": user_id}
    except JWTError:
        raise credentials_exception

@app.get("/")
async def root():
    return {"message": "Aurora API Gateway"}
