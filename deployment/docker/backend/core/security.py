from datetime import datetime, timedelta
from typing import Optional
from jose import jwt, JWTError
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

SECRET_KEY = "your-secret-key-change-in-production"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

# Простой контекст без bcrypt
pwd_context = CryptContext(schemes=["plaintext"], deprecated="auto")

# OAuth2 схема
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Простая проверка пароля (для тестов)"""
    return plain_password == hashed_password

def get_password_hash(password: str) -> str:
    """Простое хэширование (для тестов)"""
    return password

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Создаёт JWT токен"""
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def decode_token(token: str) -> Optional[dict]:
    """Декодирует JWT токен"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None

async def get_current_user(token: str = Depends(oauth2_scheme)):
    """Получает текущего пользователя из JWT токена"""
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
