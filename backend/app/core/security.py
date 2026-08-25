import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Literal

import bcrypt
from jose import JWTError, jwt

from app.core.config import get_settings

settings = get_settings()


# ---------- Password hashing (bcrypt) ----------

def hash_password(plain_password: str) -> str:
    return bcrypt.hashpw(plain_password.encode(), bcrypt.gensalt()).decode()


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(plain_password.encode(), hashed_password.encode())


# ---------- JWT access/refresh tokens ----------

def _create_token(subject: str, expires_delta: timedelta, token_type: Literal["access", "refresh"], extra: dict[str, Any] | None = None) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": subject,
        "type": token_type,
        "iat": now,
        "exp": now + expires_delta,
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_access_token(user_id: str, role: str) -> str:
    return _create_token(
        subject=user_id,
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        token_type="access",
        extra={"role": role},
    )


def create_refresh_token(user_id: str) -> str:
    return _create_token(
        subject=user_id,
        expires_delta=timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        token_type="refresh",
    )


def decode_token(token: str) -> dict[str, Any] | None:
    try:
        return jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
    except JWTError:
        return None


# ---------- OTP generation ----------

def generate_otp() -> str:
    """Cryptographically secure 6-digit OTP, zero-padded."""
    return f"{secrets.randbelow(1_000_000):06d}"


def generate_secure_token(n_bytes: int = 32) -> str:
    """For password-reset tokens, etc."""
    return secrets.token_urlsafe(n_bytes)
