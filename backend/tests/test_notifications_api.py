"""In-app notification center: GET /notifications + POST /notifications/read-all."""
import uuid
from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.core.db import get_db
from app.core.security import create_access_token
from app.main import app
from app.models.enums import NotificationType, UserRole
from app.models.social import Notification
from app.routers.notifications import LIST_LIMIT

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
    def __init__(self, one=None, all_rows=None, rowcount=0):
        self._one = one
        self._all = all_rows or []
        self.rowcount = rowcount

    def scalars(self):
        return self

    def all(self):
        return self._all

    def scalar_one_or_none(self):
        return self._one

    def first(self):
        return self._all[0] if self._all else None


class _NotificationsDb:
    def __init__(self, user, rows, rowcount=0):
        self.user = user
        self.rows = rows
        self.rowcount = rowcount
        self.statements = []
        self.commits = 0

    async def execute(self, stmt, *args, **kwargs):
        sql = str(stmt)
        self.statements.append(sql)
        if "FROM users" in sql:
            return _Result(one=self.user)
        if "FROM notifications" in sql or "UPDATE notifications" in sql:
            if sql.lstrip().upper().startswith("UPDATE"):
                return _Result(rowcount=self.rowcount)
            return _Result(all_rows=list(self.rows))
        raise AssertionError(f"unexpected query in notifications test: {sql}")

    async def commit(self):
        self.commits += 1

    async def close(self):
        pass


def _install(db):
    async def _override():
        yield db

    app.dependency_overrides[get_db] = _override


def _auth(user: _Customer) -> dict:
    token = create_access_token(str(user.id), "customer", user.token_version)
    return {"Authorization": f"Bearer {token}"}


def _notification(**overrides) -> Notification:
    defaults = dict(
        id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        type=NotificationType.order_accepted,
        title="Order Accepted",
        body="Your order ORD-1 has been accepted.",
        related_order_id=uuid.uuid4(),
        is_read=False,
        created_at=datetime.now(timezone.utc),
    )
    defaults.update(overrides)
    return Notification(**defaults)


def test_notifications_list_returns_current_users_rows_newest_first():
    user = _Customer()
    newer = _notification(type=NotificationType.delivered, title="Delivered")
    older = _notification(type=NotificationType.order_accepted, title="Order Accepted")
    db = _NotificationsDb(user, rows=[newer, older])  # stub is pre-sorted like the query
    _install(db)
    try:
        resp = client.get(f"{API}/notifications", headers=_auth(user))
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert [n["title"] for n in body] == ["Delivered", "Order Accepted"]
    assert body[0]["type"] == "delivered"
    assert body[1]["type"] == "order_accepted"
    assert body[0]["related_order_id"] == str(newer.related_order_id)
    assert body[0]["is_read"] is False
    # ISO timestamp parses back ("...Z" suffix handled for older Pythons)
    stamp = body[0]["created_at"].replace("Z", "+00:00")
    assert datetime.fromisoformat(stamp) is not None
    # Query shape: newest first, capped at 50, scoped to the current user
    query = next(s for s in db.statements if "FROM notifications" in s)
    assert "ORDER BY notifications.created_at DESC" in query
    assert "LIMIT" in query  # bound as a param; the cap is LIST_LIMIT
    assert LIST_LIMIT == 50
    assert "notifications.user_id" in query


def test_notifications_list_requires_auth():
    resp = client.get(f"{API}/notifications")
    assert resp.status_code == 401


def test_mark_all_read_returns_updated_count():
    user = _Customer()
    db = _NotificationsDb(user, rows=[], rowcount=3)
    _install(db)
    try:
        resp = client.post(f"{API}/notifications/read-all", headers=_auth(user))
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 200, resp.text
    assert resp.json() == {"updated": 3}
    assert db.commits == 1
    update_sql = next(s for s in db.statements if s.lstrip().upper().startswith("UPDATE"))
    assert "notifications.user_id" in update_sql


def test_mark_all_read_requires_auth():
    resp = client.post(f"{API}/notifications/read-all")
    assert resp.status_code == 401
