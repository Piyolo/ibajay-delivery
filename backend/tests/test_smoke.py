"""Smoke tests that run without a database.

`TestClient` is deliberately NOT used as a context manager: entering it runs
the app's lifespan, which calls `Base.metadata.create_all` and needs a live
Postgres. Outside the context manager only the request path runs, and every
route exercised here fails (or short-circuits) before any SQL executes.
"""
import asyncio
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from jose import jwt

from app.core.config import get_settings
from app.core.db import get_db
from app.core.deps import get_current_user
from app.core.security import create_access_token
from app.main import app

client = TestClient(app)

API = "/api/v1"


# --- GET /health -----------------------------------------------------------

def test_health_returns_ok():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


# --- Auth denials (no DB touched: dependency raises before any query) ------

def test_admin_route_without_token_is_401():
    response = client.get(f"{API}/admin/overview")
    assert response.status_code == 401


def test_admin_route_with_garbage_token_is_401():
    response = client.get(
        f"{API}/admin/overview", headers={"Authorization": "Bearer not-a-jwt"}
    )
    assert response.status_code == 401


def test_refresh_with_garbage_token_is_401():
    response = client.post(f"{API}/auth/refresh", json={"refresh_token": "garbage"})
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid refresh token"


# --- Rate limiting ---------------------------------------------------------

class _StubResult:
    """Pretends the query ran and found nothing -> login fails with 401."""

    def scalar_one_or_none(self):
        return None

    def first(self):
        return None

    def scalars(self):
        return self


class _StubSession:
    async def execute(self, *args, **kwargs):
        return _StubResult()

    async def commit(self):
        pass

    async def refresh(self, *args, **kwargs):
        pass

    async def add(self, *args, **kwargs):
        pass

    async def close(self):
        pass


async def _stub_get_db():
    yield _StubSession()


def test_login_trips_429_after_five_failed_attempts():
    # Stub get_db so failures come back as 401 (no Postgres needed); the
    # limiter counts those failures and 429s before touching the stub again.
    app.dependency_overrides[get_db] = _stub_get_db
    try:
        body = {"mobile_number": "09990001111", "password": "WrongPass123"}
        codes = [
            client.post(f"{API}/auth/login", json=body).status_code
            for _ in range(6)
        ]
        assert codes[:5] == [401] * 5, f"expected 5x401, got {codes}"
        assert codes[5] == 429, f"expected 429 on 6th attempt, got {codes}"
        detail = client.post(f"{API}/auth/login", json=body).json()["detail"]
        assert "failed login attempts" in detail.lower()
    finally:
        app.dependency_overrides.clear()


def test_login_budget_is_scoped_per_mobile_number():
    app.dependency_overrides[get_db] = _stub_get_db
    try:
        burnt = {"mobile_number": "09990002222", "password": "x"}
        for _ in range(5):
            client.post(f"{API}/auth/login", json=burnt)
        assert client.post(f"{API}/auth/login", json=burnt).status_code == 429

        # A different mobile number still gets its own fresh window.
        other = client.post(
            f"{API}/auth/login",
            json={"mobile_number": "09990003333", "password": "x"},
        )
        assert other.status_code == 401
    finally:
        app.dependency_overrides.clear()


def test_forgot_password_start_rate_limited_per_ip():
    # Counts requests (not failures): max 3 per minute per IP. get_db is
    # stubbed so the first three attempts never reach a database or email
    # provider; the limiter dependency runs before the handler anyway.
    app.dependency_overrides[get_db] = _stub_get_db
    try:
        codes = [
            client.post(f"{API}/auth/forgot-password/start", json={"email": "a@b.co"}).status_code
            for _ in range(4)
        ]
        assert codes[3] == 429, f"expected 429 on 4th request, got {codes}"
        assert codes[:3] == [200] * 3, f"expected 3x200 first, got {codes}"
    finally:
        app.dependency_overrides.clear()


# --- Token revocation (token_version / `tv` claim) -------------------------

class _FakeUser:
    def __init__(self, token_version: int):
        self.id = uuid.uuid4()
        self.is_active = True
        self.token_version = token_version


class _UserLookupDb:
    """Stub session that always finds one fixed user."""

    def __init__(self, user):
        self._user = user

    async def execute(self, *args, **kwargs):
        class _Result:
            def scalar_one_or_none(self_inner):
                return self._user

        return _Result()


def _token_with_claims(user, **extra_claims) -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user.id),
        "type": "access",
        "iat": now,
        "exp": now + timedelta(minutes=5),
        "role": "customer",
        **extra_claims,
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def test_token_with_matching_token_version_is_accepted():
    user = _FakeUser(token_version=0)
    token = create_access_token(str(user.id), "customer", user.token_version)
    resolved = asyncio.run(get_current_user(token=token, db=_UserLookupDb(user)))
    assert resolved is user


def test_token_missing_tv_claim_is_rejected_as_revoked():
    # Tokens minted before this deploy have no `tv` -> rejected (by design).
    user = _FakeUser(token_version=0)
    token = _token_with_claims(user)
    with pytest.raises(HTTPException) as exc:
        asyncio.run(get_current_user(token=token, db=_UserLookupDb(user)))
    assert exc.value.status_code == 401
    assert exc.value.detail == "Token has been revoked"


def test_token_with_stale_token_version_is_rejected_as_revoked():
    user = _FakeUser(token_version=1)  # password changed since the token was minted
    token = create_access_token(str(user.id), "customer", 0)
    with pytest.raises(HTTPException) as exc:
        asyncio.run(get_current_user(token=token, db=_UserLookupDb(user)))
    assert exc.value.status_code == 401
    assert exc.value.detail == "Token has been revoked"
