"""Image uploads: stored in Postgres (Render's free disk is ephemeral),
served back with long-lived cache headers. Returns absolute URLs so the
apps can use them directly as logo/banner/chat image URLs."""
import base64
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, Response, UploadFile, status
from sqlalchemy import select

from app.core.db import get_db
from app.core.deps import get_current_user
from app.models.social import Upload
from app.models.user import User

router = APIRouter(prefix="/uploads", tags=["Uploads"])

MAX_BYTES = 3 * 1024 * 1024  # 3 MB


def _detect_image_type(raw: bytes) -> str | None:
    """Sniffs the image format from magic bytes.

    Some Android pickers hand us files with no extension, so the multipart
    part arrives without a useful Content-Type header — trusting the
    declared type wrongly rejects real JPEG/PNG uploads. The bytes don't
    lie.
    """
    if raw[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if raw[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if len(raw) >= 12 and raw[:4] == b"RIFF" and raw[8:12] == b"WEBP":
        return "image/webp"
    return None


@router.post("", status_code=status.HTTP_201_CREATED)
async def upload_image(
    request: Request,
    file: UploadFile,
    user: User = Depends(get_current_user),
    db=Depends(get_db),
):
    raw = await file.read()
    if len(raw) > MAX_BYTES:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "Image must be under 3 MB")

    content_type = _detect_image_type(raw)
    if content_type is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Only JPEG, PNG, or WebP images are allowed")

    upload = Upload(
        uploaded_by=user.id,
        content_type=content_type,
        data_base64=base64.b64encode(raw).decode(),
        byte_size=len(raw),
    )
    db.add(upload)
    await db.commit()
    await db.refresh(upload)

    base = str(request.base_url).rstrip("/")
    return {"url": f"{base}/api/v1/uploads/{upload.id}"}


@router.get("/{upload_id}")
async def get_image(upload_id: uuid.UUID, db=Depends(get_db)):
    result = await db.execute(select(Upload).where(Upload.id == upload_id))
    upload = result.scalar_one_or_none()
    if not upload:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Upload not found")

    return Response(
        content=base64.b64decode(upload.data_base64),
        media_type=upload.content_type,
        headers={"Cache-Control": "public, max-age=31536000, immutable"},
    )
