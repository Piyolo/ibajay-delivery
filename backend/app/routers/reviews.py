"""Order reviews: a customer rates a completed order (1-5 stars + optional
comment); anyone can read a vendor's reviews; the vendor can list their own.
Ratings are unique per order and only allowed once the order is delivered."""
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.deps import get_current_user, require_customer
from app.models.enums import OrderStatus
from app.models.order import Order
from app.models.social import Rating, Review
from app.models.user import User
from app.models.vendor import Vendor

router = APIRouter(tags=["Reviews"])

_REVIEWABLE = {OrderStatus.delivered, OrderStatus.completed}


class ReviewIn(BaseModel):
    stars: int
    comment: str | None = None

    @field_validator("stars")
    @classmethod
    def valid_stars(cls, v: int) -> int:
        if not 1 <= v <= 5:
            raise ValueError("stars must be between 1 and 5")
        return v


class ReviewOut(BaseModel):
    id: uuid.UUID
    order_id: uuid.UUID | None = None
    customer_name: str | None = None
    stars: int
    comment: str | None
    vendor_response: str | None
    created_at: datetime

    class Config:
        from_attributes = True


def _first_name(full_name: str | None) -> str | None:
    return full_name.split(" ")[0] if full_name else None


async def _load_review_for_order(order_id: uuid.UUID, db: AsyncSession) -> ReviewOut | None:
    result = await db.execute(
        select(Rating, Review, User.full_name)
        .join(Review, Review.rating_id == Rating.id)
        .join(User, User.id == Rating.customer_id)
        .where(Rating.order_id == order_id)
    )
    row = result.first()
    if not row:
        return None
    rating, review, name = row
    return ReviewOut(
        id=review.id,
        order_id=rating.order_id,
        customer_name=_first_name(name),
        stars=rating.stars,
        comment=review.comment,
        vendor_response=review.vendor_response,
        created_at=review.created_at,
    )


@router.post("/orders/{order_id}/review", response_model=ReviewOut, status_code=status.HTTP_201_CREATED)
async def review_order(
    order_id: uuid.UUID,
    payload: ReviewIn,
    user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Order).where(Order.id == order_id))
    order = result.scalar_one_or_none()
    if not order or order.customer_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")
    if order.status not in _REVIEWABLE:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You can review after your order is delivered")

    existing = await _load_review_for_order(order_id, db)
    if existing:
        raise HTTPException(status.HTTP_409_CONFLICT, "This order was already reviewed")

    rating = Rating(
        order_id=order.id,
        customer_id=user.id,
        vendor_id=order.vendor_id,
        stars=payload.stars,
    )
    db.add(rating)
    await db.flush()
    review = Review(rating_id=rating.id, comment=payload.comment)
    db.add(review)

    # Maintain the vendor's aggregate rating.
    vendor_result = await db.execute(select(Vendor).where(Vendor.id == order.vendor_id))
    vendor = vendor_result.scalar_one_or_none()
    if vendor:
        count = vendor.total_reviews or 0
        current = float(vendor.average_rating or 0)
        new_avg = ((current * count) + payload.stars) / (count + 1) if count + 1 > 0 else payload.stars
        vendor.average_rating = round(min(5.0, new_avg), 2)
        vendor.total_reviews = count + 1

    await db.commit()
    return ReviewOut(
        id=review.id,
        order_id=order.id,
        customer_name=_first_name(user.full_name),
        stars=payload.stars,
        comment=payload.comment,
        vendor_response=None,
        created_at=review.created_at,
    )


@router.get("/orders/{order_id}/review", response_model=ReviewOut)
async def get_order_review(
    order_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """The review attached to an order (404 when not yet reviewed)."""
    result = await db.execute(select(Order).where(Order.id == order_id))
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")

    vendor_result = await db.execute(select(Vendor).where(Vendor.id == order.vendor_id))
    vendor = vendor_result.scalar_one_or_none()
    if order.customer_id != user.id and (not vendor or vendor.owner_id != user.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not authorized")

    review = await _load_review_for_order(order_id, db)
    if not review:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No review yet")
    return review


@router.get("/vendors/{vendor_id}/reviews", response_model=list[ReviewOut])
async def vendor_reviews(
    vendor_id: uuid.UUID,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
):
    """Public reviews for a store (newest first)."""
    result = await db.execute(
        select(Rating, Review, User.full_name)
        .join(Review, Review.rating_id == Rating.id)
        .join(User, User.id == Rating.customer_id)
        .where(Rating.vendor_id == vendor_id)
        .order_by(Rating.created_at.desc())
        .limit(limit)
    )
    return [
        ReviewOut(
            id=review.id,
            order_id=rating.order_id,
            customer_name=_first_name(name),
            stars=rating.stars,
            comment=review.comment,
            vendor_response=review.vendor_response,
            created_at=review.created_at,
        )
        for rating, review, name in result.all()
    ]
