import httpx
from fastapi import HTTPException, status

from app.core.config import get_settings

settings = get_settings()

RESEND_API_URL = "https://api.resend.com/emails"


async def send_email(to: str, subject: str, html: str) -> None:
    """
    Send an email via the Resend API.
    In development (no API key set), logs to console instead of failing hard,
    so local testing doesn't require a Resend account.
    """
    if not settings.RESEND_API_KEY:
        print(f"[DEV EMAIL] to={to} subject={subject}\n{html}\n")
        return

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
        if resp.status_code >= 300:
            # Surface Resend's reason (unverified domain, sandbox restriction
            # on the recipient, bad API key...) instead of a bare 500.
            detail = resp.json().get("message", resp.text) if resp.text else resp.text
            raise HTTPException(
                status.HTTP_502_BAD_GATEWAY,
                f"Email delivery failed: {detail}",
            )


async def send_waitlist_confirmation(to: str, name: str, interest: str) -> None:
    """Confirmation email to the person who joined the pre-launch waitlist."""
    kind = (
        "As a business owner, you'll get early access to set up your storefront"
        if interest == "vendor"
        else "You'll be among the first to order from local stores around town"
    )
    subject = "You're on the Ibajay Eats waitlist!"
    html = f"""
    <div style="font-family: sans-serif; max-width: 480px; margin: auto; color: #1D1A17;">
      <h2 style="color: #E85D2A;">Salamat, {name}!</h2>
      <p>You're officially on the <strong>Ibajay Eats</strong> waitlist.</p>
      <p>{kind}.</p>
      <p>We'll email you the moment we launch in Ibajay, Aklan.</p>
      <p style="color: #888; font-size: 12px;">You received this because someone used this
      email to join the Ibajay Eats waitlist at ibajayeats.linkpc.net.</p>
    </div>
    """
    await send_email(to, subject, html)


async def send_waitlist_alert(name: str, email: str, interest: str) -> None:
    """Notify the owner that a new person joined the waitlist."""
    settings = get_settings()
    notify_to = settings.WAITLIST_NOTIFY_EMAIL or settings.EMAIL_FROM
    subject = f"New waitlist signup ({interest}): {name}"
    html = f"""
    <div style="font-family: sans-serif; max-width: 480px;">
      <h2>New waitlist signup</h2>
      <ul>
        <li><strong>Name:</strong> {name}</li>
        <li><strong>Email:</strong> {email}</li>
        <li><strong>Interest:</strong> {interest}</li>
      </ul>
      <p>Total signups so far: check the Neon console (waitlist_entries table).</p>
    </div>
    """
    await send_email(notify_to, subject, html)


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
    await send_email(to, subject, html)
