import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.deps import require_customer
from app.models.user import Address, User

router = APIRouter(prefix="/addresses", tags=["Addresses"])


class AddressIn(BaseModel):
    label: str = "Home"
    full_address: str
    latitude: float
    longitude: float
    landmark: str | None = None
    is_default: bool = False


class AddressOut(AddressIn):
    id: uuid.UUID

    class Config:
        from_attributes = True


@router.get("", response_model=list[AddressOut])
async def list_addresses(user: User = Depends(require_customer), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Address).where(Address.user_id == user.id))
    return result.scalars().all()


@router.post("", response_model=AddressOut, status_code=status.HTTP_201_CREATED)
async def add_address(payload: AddressIn, user: User = Depends(require_customer), db: AsyncSession = Depends(get_db)):
    if payload.is_default:
        existing = await db.execute(select(Address).where(Address.user_id == user.id, Address.is_default == True))  # noqa: E712
        for addr in existing.scalars().all():
            addr.is_default = False

    address = Address(user_id=user.id, **payload.model_dump())
    db.add(address)
    await db.commit()
    await db.refresh(address)
    return address


@router.delete("/{address_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_address(address_id: uuid.UUID, user: User = Depends(require_customer), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Address).where(Address.id == address_id, Address.user_id == user.id))
    address = result.scalar_one_or_none()
    if not address:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Address not found")
    await db.delete(address)
    await db.commit()
