import re
import uuid

from pydantic import BaseModel, EmailStr, field_validator


class RegisterStart(BaseModel):
    full_name: str
    mobile_number: str
    email: EmailStr


class VerifyOtp(BaseModel):
    email: EmailStr
    otp_code: str
    purpose: str = "registration"


class SetPassword(BaseModel):
    email: EmailStr
    password: str
    confirm_password: str

    @field_validator("password")
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


class LoginRequest(BaseModel):
    mobile_number: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: uuid.UUID
    role: str


class RefreshRequest(BaseModel):
    refresh_token: str


class ForgotPasswordStart(BaseModel):
    email: EmailStr


class ResetPassword(BaseModel):
    email: EmailStr
    otp_code: str
    new_password: str
    confirm_password: str

    @field_validator("new_password")
    @classmethod
    def validate_password_strength(cls, v: str) -> str:
        if len(v) < 8 or not re.search(r"[A-Z]", v) or not re.search(r"[a-z]", v) or not re.search(r"\d", v):
            raise ValueError("Password must be 8+ chars with upper, lower, and a number")
        return v
