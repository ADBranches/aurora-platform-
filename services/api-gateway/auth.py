from jose import jwt, JWTError
from datetime import datetime, timedelta
from fastapi import Depends, HTTPException, status  # Import Depends, HTTPException, and status
from fastapi.security import OAuth2PasswordBearer  # Import OAuth2PasswordBearer
from dotenv import load_dotenv  # Import load_dotenv
import os
load_dotenv()
SECRET_KEY = os.getenv("JWT_SECRET_KEY")  # Set in .env
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")  # Define oauth2_scheme
SECRET_KEY = os.getenv("JWT_SECRET_KEY")  # Set in .env
if not SECRET_KEY:
    raise ValueError("JWT_SECRET_KEY environment variable is not set")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    if not isinstance(SECRET_KEY, str):
        raise ValueError("SECRET_KEY must be a valid string")
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(token: str):
    if not SECRET_KEY:
        raise ValueError("SECRET_KEY is not set")
    return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])

def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = verify_token(token)
        user_id = payload.get("sub")
        if not isinstance(user_id, str):
            raise credentials_exception
        if user_id is None:
            raise credentials_exception
        return {"user_id": user_id}
    except JWTError:
        raise credentials_exception
    