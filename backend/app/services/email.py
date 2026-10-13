import logging

import httpx
from fastapi import HTTPException, status

from app.core.config import get_settings

settings = get_settings()
logger = logging.getLogger(__name__)

RESEND_API_URL = "https://api.resend.com/emails"


async def send_email(to: str, subject: str, html: str) -> None:
    """
    Send an email via the Resend API.
    In development (no API key set), logs to console instead of failing hard,
    so local testing doesn't require a Resend account.

    Every failure mode (Resend rejection, timeout, connection error) is
    logged with the recipient + subject and raised as a 502 so callers can
    tell the client the message was NOT delivered instead of returning a
    success payload.
    """
    if not settings.RESEND_API_KEY:
        print(f"[DEV EMAIL] to={to} subject={subject}\n{html}\n")
        return

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(
                RESEND_API_URL,
                headers={"Authorization": f"Bearer {settings.RESEND_API_KEY}"},
                json={
                    "from": settings.EMAIL_FROM,
                    "to": [to],
                    "subject": subject,
                    "html": html,
                },
            )
    except httpx.HTTPError as exc:
        # Timeouts / DNS / connection resets used to surface as an unhandled
        # 500 with no context. Log loudly and report a 502 to the client.
        logger.exception("Resend request failed: to=%s subject=%r error=%r", to, subject, exc)
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            f"Email delivery failed: {exc.__class__.__name__}: {exc}",
        ) from exc

    if resp.status_code >= 300:
        # Surface Resend's reason (unverified domain, sandbox restriction
        # on the recipient, bad API key...) instead of a bare 500, and log
        # it so a failing provider is never invisible in the server logs.
        detail = resp.text
        try:
            payload = resp.json()
            if isinstance(payload, dict):
                detail = payload.get("message") or payload.get("name") or detail
        except ValueError:
            pass  # non-JSON error body: keep resp.text
        logger.error(
            "Resend rejected the email: to=%s subject=%r status=%s detail=%s",
            to,
            subject,
            resp.status_code,
            detail,
        )
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            f"Email delivery failed: {detail}",
        )


async def send_otp_email(to: str, otp_code: str, purpose: str = "registration") -> None:
    subject = "Verify Your Account" if purpose == "registration" else "Reset Your Password"
    html = f"""
    <div style="font-family: sans-serif; max-width: 480px; margin: auto;">
      <h2>{subject}</h2>
      <p>Your verification code is:</p>
      <p style="font-size: 32px; font-weight: bold; letter-spacing: 4px;">{otp_code}</p>
      <p>This code will expire in {settings.OTP_EXPIRE_MINUTES} minutes.</p>
      <p style="color: #888; font-size: 12px;">If you didn't request this, you can safely ignore this email.</p>
    </div>
    """
    try:
        await send_email(to, subject, html)
    except Exception:
        # Purpose + recipient context for the OTP flows specifically (the
        # generic send_email log above has subject/status but not purpose).
        logger.exception("OTP email failed to send: to=%s purpose=%s", to, purpose)
        raise
