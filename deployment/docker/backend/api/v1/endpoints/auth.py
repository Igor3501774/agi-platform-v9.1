from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from datetime import timedelta
from jose import JWTError, jwt
from pydantic import BaseModel

from core.security import create_access_token, get_current_user, ACCESS_TOKEN_EXPIRE_MINUTES

router = APIRouter(tags=["auth"])

class Token(BaseModel):
    access_token: str
    token_type: str

USERS = {
    "admin": {"username": "admin", "password": "admin", "disabled": False},
    "user": {"username": "user", "password": "user", "disabled": False}
}

@router.post("/token", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    user = USERS.get(form_data.username)
    if not user or user.get("disabled", False):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if form_data.password != user["password"]:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user["username"]}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}