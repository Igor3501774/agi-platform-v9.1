from fastapi import APIRouter, Depends, HTTPException, status, Form
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from datetime import datetime, timedelta
from jose import JWTError, jwt
from typing import Optional
import os
import time
from collections import defaultdict

from backend.core.security import SECRET_KEY, ALGORITHM, create_access_token, decode_token

router = APIRouter()

class Token(BaseModel):
    access_token: str
    token_type: str

# ============================================================
# ЗАЩИТА ОТ БРУТФОРСА
# ============================================================
FAILED_LOGIN = defaultdict(int)
LAST_FAILED = defaultdict(float)

def check_bruteforce(username: str):
    now = time.time()
    if FAILED_LOGIN[username] >= 5 and now - LAST_FAILED[username] < 300:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many failed attempts. Try again later."
        )

def record_failed_login(username: str):
    FAILED_LOGIN[username] += 1
    LAST_FAILED[username] = time.time()

def record_success_login(username: str):
    FAILED_LOGIN[username] = 0

# ============================================================
# ТЕСТОВЫЕ ПОЛЬЗОВАТЕЛИ
# ============================================================
VALID_USERS = {
    "admin": "admin123",
    "test": "test123",
    "user": "user123"
}

# ============================================================
# LOGIN
# ============================================================
@router.post("/token", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    username = form_data.username
    password = form_data.password

    check_bruteforce(username)

    if username in VALID_USERS and password == VALID_USERS[username]:
        record_success_login(username)
        access_token = create_access_token(
            data={
                "sub": username,
                "plan": "free" if username != "admin" else "pro"
            }
        )
        return {"access_token": access_token, "token_type": "bearer"}
    else:
        record_failed_login(username)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

# ============================================================
# JWT REFRESH
# ============================================================
@router.post("/refresh", response_model=Token)
async def refresh_access_token(refresh_token: str = Form(...)):
    try:
        payload = decode_token(refresh_token)
        if not payload:
            raise HTTPException(status_code=401, detail="Invalid refresh token")

        username = payload.get("sub")
        plan = payload.get("plan", "free")

        new_token = create_access_token(data={"sub": username, "plan": plan})
        return {"access_token": new_token, "token_type": "bearer"}
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

# ============================================================
# OAUTH2 SCHEME
# ============================================================
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")

# ============================================================
# GET CURRENT USER
# ============================================================
async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_token(token)
        if not payload:
            raise credentials_exception
        username: str = payload.get("sub")
        plan: str = payload.get("plan", "free")
        if username is None:
            raise credentials_exception
        return {"username": username, "plan": plan}
    except JWTError:
        raise credentials_exception

# ============================================================
# GET ME
# ============================================================
@router.get("/me")
async def get_me(current_user: dict = Depends(get_current_user)):
    return {
        "username": current_user["username"],
        "plan": current_user["plan"],
        "email": f"{current_user['username']}@agi.com"
    }
