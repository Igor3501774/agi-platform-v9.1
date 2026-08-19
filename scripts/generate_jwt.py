#!/usr/bin/env python3
import secrets
import re
from pathlib import Path

def generate_jwt_key(length: int = 72) -> str:
    return secrets.token_urlsafe(length)

def update_env_file(env_path: Path, key: str):
    if not env_path.exists():
        env_path.write_text(f"JWT_SECRET_KEY={key}\n", encoding='utf-8')
        print(f"✅ .env создан и JWT_SECRET_KEY установлен")
        return
    content = env_path.read_text(encoding='utf-8')
    pattern = r'^JWT_SECRET_KEY=.*$'
    replacement = f'JWT_SECRET_KEY={key}'
    if re.search(pattern, content, re.MULTILINE):
        new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
    else:
        new_content = content + f"\n{replacement}\n"
    env_path.write_text(new_content, encoding='utf-8')
    print(f"✅ JWT_SECRET_KEY обновлён (длина: {len(key)} символов)")

if __name__ == "__main__":
    key = generate_jwt_key(72)
    env_path = Path(__file__).parent.parent / ".env"
    update_env_file(env_path, key)
    print(f"🔑 Новый ключ (фрагмент): {key[:20]}...{key[-20:]}")
