import asyncio

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr, field_validator
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.db import get_db
from app.models.waitlist import WaitlistEntry
from app.services.email import send_waitlist_alert, send_waitlist_confirmation

router = APIRouter(prefix="/waitlist", tags=["Waitlist"])
settings = get_settings()


class WaitlistJoin(BaseModel):
    name: str
    email: EmailStr
    interest: str  # "customer" | "vendor"

    @field_validator("name")
    @classmethod
    def name_not_blank(cls, v: str) -> str:
        v = v.strip()
        if not 1 <= len(v) <= 120:
            raise ValueError("name must be 1-120 characters")
        return v

    @field_validator("interest")
    @classmethod
    def valid_interest(cls, v: str) -> str:
        if v not in ("customer", "vendor"):
            raise ValueError("interest must be 'customer' or 'vendor'")
        return v


class WaitlistJoined(BaseModel):
    message: str
    already_registered: bool = False


class WaitlistCount(BaseModel):
    count: int


@router.get("/count", response_model=WaitlistCount)
async def waitlist_count(db: AsyncSession = Depends(get_db)):
    """Public signup counter for the homepage. Only the total — no personal data."""
    total = await db.scalar(select(func.count()).select_from(WaitlistEntry))
    return WaitlistCount(count=total or 0)


@router.post("", response_model=WaitlistJoined, status_code=status.HTTP_200_OK)
async def join_waitlist(payload: WaitlistJoin, db: AsyncSession = Depends(get_db)):
    """Add an email to the pre-launch waitlist. Idempotent per email."""
    existing = await db.execute(select(WaitlistEntry).where(WaitlistEntry.email == payload.email))
    if existing.scalar_one_or_none():
        return WaitlistJoined(
            message="You're already on the list — we'll let you know when we launch.",
            already_registered=True,
        )

    entry = WaitlistEntry(name=payload.name.strip(), email=str(payload.email).lower(), interest=payload.interest)
    db.add(entry)
    try:
        await db.commit()
    except IntegrityError:
        # Raced another request for the same email.
        await db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "This email is already on the waitlist")

    # Emails are best-effort: a Resend outage must never fail the signup itself.
    async def _emails():
        try:
            await send_waitlist_confirmation(entry.email, entry.name, entry.interest)
            await send_waitlist_alert(entry.name, entry.email, entry.interest)
        except Exception:
            pass  # logged by the email layer on hard failures; signup still counts

    asyncio.create_task(_emails())

    return WaitlistJoined(message="You're on the list — salamat! We'll email you when Ibajay Eats launches.")
