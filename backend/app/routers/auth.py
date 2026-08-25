from datetime import datetime, timedelta, timezone
import re

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.db import get_db
from app.core.deps import get_current_user
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    generate_otp,
    hash_password,
    verify_password,
)
from app.models.enums import UserRole
from app.models.user import EmailVerification, User
from app.schemas.auth import (
    ForgotPasswordStart,
    LoginRequest,
    RefreshRequest,
    RegisterStart,
    ResetPassword,
    SetPassword,
    TokenResponse,
    VerifyOtp,
)
from app.services.email import send_otp_email

router = APIRouter(prefix="/auth", tags=["Authentication"])
settings = get_settings()


# ---------------------------------------------------------------------------
# Step 1: collect name / mobile / email, issue OTP
# ---------------------------------------------------------------------------
@router.post("/register/start", status_code=status.HTTP_200_OK)
async def register_start(payload: RegisterStart, db: AsyncSession = Depends(get_db)):
    existing = await db.execute(
        select(User).where((User.email == payload.email) | (User.mobile_number == payload.mobile_number))
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status.HTTP_409_CONFLICT, "An account with this email or mobile number already exists")

    otp_code = generate_otp()
    verification = EmailVerification(
        email=payload.email,
        otp_code=otp_code,
        purpose="registration",
        pending_payload={"full_name": payload.full_name, "mobile_number": payload.mobile_number},
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRE_MINUTES),
    )
    db.add(verification)
    await db.commit()

    await send_otp_email(payload.email, otp_code, purpose="registration")
    return {"message": "OTP sent to your email", "email": payload.email}


# ---------------------------------------------------------------------------
# Step 2/3: verify OTP
# ---------------------------------------------------------------------------
@router.post("/register/verify-otp", status_code=status.HTTP_200_OK)
async def verify_registration_otp(payload: VerifyOtp, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(EmailVerification)
        .where(
            EmailVerification.email == payload.email,
            EmailVerification.purpose == payload.purpose,
            EmailVerification.is_used == False,  # noqa: E712
        )
        .order_by(EmailVerification.created_at.desc())
    )
    verification = result.scalars().first()

    if not verification:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "No pending verification found. Please request a new OTP.")

    if verification.attempts >= settings.OTP_MAX_ATTEMPTS:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Maximum OTP attempts exceeded. Please request a new code.")

    if datetime.now(timezone.utc) > verification.expires_at.replace(tzinfo=timezone.utc):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "OTP has expired. Please request a new code.")

    verification.attempts += 1

    if verification.otp_code != payload.otp_code:
        await db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Incorrect OTP code")

    verification.is_used = True
    await db.commit()
    return {"message": "OTP verified", "email": payload.email}


# ---------------------------------------------------------------------------
# Step 4: set password -> create the user account
# ---------------------------------------------------------------------------
@router.post("/register/set-password", response_model=TokenResponse)
async def set_password(payload: SetPassword, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(EmailVerification)
        .where(
            EmailVerification.email == payload.email,
            EmailVerification.purpose == "registration",
            EmailVerification.is_used == True,  # noqa: E712
        )
        .order_by(EmailVerification.created_at.desc())
    )
    verification = result.scalars().first()
    if not verification or not verification.pending_payload:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Please verify your email OTP before setting a password")

    existing = await db.execute(select(User).where(User.email == payload.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status.HTTP_409_CONFLICT, "Account already exists")

    user = User(
        full_name=verification.pending_payload["full_name"],
        mobile_number=verification.pending_payload["mobile_number"],
        email=payload.email,
        password_hash=hash_password(payload.password),
        role=UserRole.customer,
        is_email_verified=True,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    return TokenResponse(
        access_token=create_access_token(str(user.id), user.role.value),
        refresh_token=create_refresh_token(str(user.id)),
        user_id=user.id,
        role=user.role.value,
    )


# ---------------------------------------------------------------------------
# Login (mobile number + password)
# ---------------------------------------------------------------------------
@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.mobile_number == payload.mobile_number))
    user = result.scalar_one_or_none()

    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid mobile number or password")
    if not user.is_active:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Account is deactivated")

    return TokenResponse(
        access_token=create_access_token(str(user.id), user.role.value),
        refresh_token=create_refresh_token(str(user.id)),
        user_id=user.id,
        role=user.role.value,
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(payload: RefreshRequest, db: AsyncSession = Depends(get_db)):
    data = decode_token(payload.refresh_token)
    if not data or data.get("type") != "refresh":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid refresh token")

    result = await db.execute(select(User).where(User.id == data["sub"]))
    user = result.scalar_one_or_none()
    if not user or not user.is_active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User not found or inactive")

    return TokenResponse(
        access_token=create_access_token(str(user.id), user.role.value),
        refresh_token=create_refresh_token(str(user.id)),
        user_id=user.id,
        role=user.role.value,
    )


# ---------------------------------------------------------------------------
# Forgot password: email -> OTP -> verify -> new password
# ---------------------------------------------------------------------------
@router.post("/forgot-password/start")
async def forgot_password_start(payload: ForgotPasswordStart, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()
    if not user:
        # Don't reveal whether the email exists
        return {"message": "If that email is registered, a code has been sent."}

    otp_code = generate_otp()
    verification = EmailVerification(
        email=payload.email,
        otp_code=otp_code,
        purpose="password_reset",
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRE_MINUTES),
    )
    db.add(verification)
    await db.commit()

    await send_otp_email(payload.email, otp_code, purpose="password_reset")
    return {"message": "If that email is registered, a code has been sent."}


@router.post("/forgot-password/reset")
async def forgot_password_reset(payload: ResetPassword, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(EmailVerification)
        .where(
            EmailVerification.email == payload.email,
            EmailVerification.purpose == "password_reset",
            EmailVerification.is_used == False,  # noqa: E712
        )
        .order_by(EmailVerification.created_at.desc())
    )
    verification = result.scalars().first()
    if not verification:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "No pending reset request found")
    if datetime.now(timezone.utc) > verification.expires_at.replace(tzinfo=timezone.utc):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Code expired. Please request a new one.")
    if verification.otp_code != payload.otp_code:
        verification.attempts += 1
        await db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Incorrect code")

    user_result = await db.execute(select(User).where(User.email == payload.email))
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Account not found")

    user.password_hash = hash_password(payload.new_password)
    verification.is_used = True
    await db.commit()
    return {"message": "Password reset successful. You can now log in."}


# ---------------------------------------------------------------------------
# Authenticated profile: the mobile apps call this right after login /
# registration (and on session restore) to hydrate the user profile.
# ---------------------------------------------------------------------------
class MeOut(BaseModel):
    id: str
    full_name: str
    mobile_number: str
    email: str
    role: str
    is_email_verified: bool


@router.get("/me", response_model=MeOut)
async def get_me(current_user: User = Depends(get_current_user)):
    return MeOut(
        id=str(current_user.id),
        full_name=current_user.full_name,
        mobile_number=current_user.mobile_number,
        email=current_user.email,
        role=current_user.role.value,
        is_email_verified=current_user.is_email_verified,
    )


class ChangePassword(BaseModel):
    current_password: str
    new_password: str
    confirm_password: str

    @field_validator("new_password")
    @classmethod
    def validate_password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain an uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain a lowercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain a number")
        return v

    @field_validator("confirm_password")
    @classmethod
    def passwords_match(cls, v: str, info) -> str:
        if "password" in info.data and v != info.data["password"]:
            raise ValueError("Passwords do not match")
        return v


@router.post("/change-password")
async def change_password(
    payload: ChangePassword,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not verify_password(payload.current_password, current_user.password_hash):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Current password is incorrect")

    current_user.password_hash = hash_password(payload.new_password)
    await db.commit()
    return {"message": "Password changed successfully"}
