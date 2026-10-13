"""Profile update (PUT /auth/profile) + OTP email reliability fixes."""
import asyncio
import json
import logging
import uuid

import httpx
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.core.db import get_db
from app.core.security import create_access_token
from app.main import app
from app.models.enums import UserRole
from app.models.user import EmailVerification
from app.routers import auth as auth_router
from app.services import email as email_service

client = TestClient(app)

API = "/api/v1"


class _Customer:
    def __init__(self):
        self.id = uuid.uuid4()
        self.full_name = "Juan Dela Cruz"
        self.mobile_number = "09171234567"
        self.email = "juan@example.com"
        self.role = UserRole.customer
        self.is_active = True
        self.is_email_verified = True
        self.token_version = 0


class _Result:
    def __init__(self, one=None):
        self._one = one

    def scalar_one_or_none(self):
        return self._one

    def scalars(self):
        return self

    def all(self):
        return [self._one] if self._one else []

    def first(self):
        return self._one


class _StubDb:
    """Session stub that resolves the current user and records writes."""

    def __init__(self, user):
        self.user = user
        self.added = []
        self.commits = 0
        self.rolled_back = False

    async def execute(self, stmt, *args, **kwargs):
        sql = str(stmt)
        if "FROM users" in sql:
            return _Result(one=self.user)
        raise AssertionError(f"unexpected query: {sql}")

    def add(self, obj):
        self.added.append(obj)

    async def commit(self):
        self.commits += 1

    async def rollback(self):
        self.rolled_back = True

    async def refresh(self, obj, attribute_names=None):
        pass

    async def close(self):
        pass


def _install(db: _StubDb):
    async def _override():
        yield db

    app.dependency_overrides[get_db] = _override


def _auth(user: _Customer) -> dict:
    token = create_access_token(str(user.id), "customer", user.token_version)
    return {"Authorization": f"Bearer {token}"}


# --- PUT /auth/profile ------------------------------------------------------

def test_profile_update_persists_trimmed_name():
    user = _Customer()
    db = _StubDb(user)
    _install(db)
    try:
        resp = client.put(
            f"{API}/auth/profile",
            json={"full_name": "  Maria Clara Santos  "},
            headers=_auth(user),
        )
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 200, resp.text
    body = resp.json()
    # Same shape as GET /auth/me, with the trimmed, persisted name
    assert set(body) == {
        "id",
        "full_name",
        "mobile_number",
        "email",
        "role",
        "is_email_verified",
    }
    assert body["full_name"] == "Maria Clara Santos"
    assert body["id"] == str(user.id)
    assert body["role"] == "customer"
    assert user.full_name == "Maria Clara Santos"  # written to the user row
    assert db.commits == 1


def test_profile_update_rejects_whitespace_only_name():
    user = _Customer()
    db = _StubDb(user)
    _install(db)
    try:
        resp = client.put(
            f"{API}/auth/profile",
            json={"full_name": "   "},
            headers=_auth(user),
        )
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 422
    assert db.commits == 0


def test_profile_update_rejects_too_short_name():
    user = _Customer()
    db = _StubDb(user)
    _install(db)
    try:
        resp = client.put(
            f"{API}/auth/profile",
            json={"full_name": "J"},
            headers=_auth(user),
        )
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 422
    assert db.commits == 0


def test_profile_update_requires_auth():
    resp = client.put(f"{API}/auth/profile", json={"full_name": "Maria Santos"})
    assert resp.status_code == 401


# --- OTP email reliability --------------------------------------------------

REGISTER_BODY = {
    "full_name": "Juan Dela Cruz",
    "mobile_number": "09171234567",
    "email": "juan@example.com",
}


def test_register_start_rolls_back_otp_row_and_returns_502_when_send_fails(monkeypatch):
    db = _StubDb(user=None)  # no existing account -> proceeds to send
    _install(db)

    async def _boom(to, otp_code, purpose="registration"):
        raise HTTPException(502, "Email delivery failed: Resend said no")

    monkeypatch.setattr(auth_router, "send_otp_email", _boom)
    try:
        resp = client.post(f"{API}/auth/register/start", json=REGISTER_BODY)
    finally:
        app.dependency_overrides.clear()

    # Failure instead of a false "OTP sent" success message...
    assert resp.status_code == 502
    assert "Email delivery failed" in resp.json()["detail"]
    # ...and the pending email_verifications row is rolled back, not committed.
    assert db.rolled_back is True
    assert db.commits == 0


def test_register_start_commits_otp_row_only_after_a_successful_send(monkeypatch):
    db = _StubDb(user=None)
    _install(db)

    sent = []

    async def _send(to, otp_code, purpose="registration"):
        sent.append((to, otp_code, purpose))

    monkeypatch.setattr(auth_router, "send_otp_email", _send)
    try:
        resp = client.post(f"{API}/auth/register/start", json=REGISTER_BODY)
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 200, resp.text
    assert resp.json()["message"] == "OTP sent to your email"
    assert db.commits == 1
    assert db.rolled_back is False
    assert any(isinstance(o, EmailVerification) for o in db.added)
    assert sent and sent[0][0] == "juan@example.com"
    assert sent[0][2] == "registration"
    assert len(sent[0][1]) == 6


def test_forgot_password_start_rolls_back_and_returns_502_when_send_fails(monkeypatch):
    user = _Customer()
    db = _StubDb(user=user)  # account exists -> attempts the send
    _install(db)

    async def _boom(to, otp_code, purpose="password_reset"):
        raise HTTPException(502, "Email delivery failed: Resend said no")

    monkeypatch.setattr(auth_router, "send_otp_email", _boom)
    try:
        resp = client.post(f"{API}/auth/forgot-password/start", json={"email": user.email})
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 502
    assert db.rolled_back is True
    assert db.commits == 0


# --- services/email.py: loud logs + 502 -------------------------------------

class _FakeResponse:
    def __init__(self, status_code, payload):
        self.status_code = status_code
        self.payload = payload
        self.text = json.dumps(payload)

    def json(self):
        return self.payload


def _fake_client(post):
    class _Client:
        def __init__(self, *args, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *exc):
            return False

        async def post(self, *args, **kwargs):
            return post()

    return _Client


def test_send_email_logs_and_raises_502_when_resend_rejects(monkeypatch, caplog):
    monkeypatch.setattr(email_service.settings, "RESEND_API_KEY", "test-key")
    monkeypatch.setattr(
        email_service.httpx,
        "AsyncClient",
        _fake_client(lambda: _FakeResponse(400, {"message": "domain is not verified"})),
    )
    caplog.set_level(logging.ERROR, logger="app.services.email")

    with pytest.raises(HTTPException) as exc:
        asyncio.run(
            email_service.send_email("dest@example.com", "Verify Your Account", "<p>123456</p>")
        )

    assert exc.value.status_code == 502
    assert "domain is not verified" in str(exc.value.detail)
    assert "dest@example.com" in caplog.text  # recipient is visible in the log


def test_send_email_logs_and_raises_502_on_network_failure(monkeypatch, caplog):
    def _raise():
        raise httpx.ConnectError("connection refused")

    monkeypatch.setattr(email_service.settings, "RESEND_API_KEY", "test-key")
    monkeypatch.setattr(email_service.httpx, "AsyncClient", _fake_client(_raise))
    caplog.set_level(logging.ERROR, logger="app.services.email")

    with pytest.raises(HTTPException) as exc:
        asyncio.run(email_service.send_email("dest@example.com", "Hi", "<p>x</p>"))

    assert exc.value.status_code == 502
    assert "dest@example.com" in caplog.text


def test_send_otp_email_logs_the_purpose_on_failure(monkeypatch, caplog):
    async def _boom(to, subject, html):
        raise HTTPException(502, "Email delivery failed: boom")

    monkeypatch.setattr(email_service, "send_email", _boom)
    caplog.set_level(logging.ERROR, logger="app.services.email")

    with pytest.raises(HTTPException):
        asyncio.run(
            email_service.send_otp_email("dest@example.com", "123456", purpose="password_reset")
        )

    assert "purpose=password_reset" in caplog.text
    assert "dest@example.com" in caplog.text
