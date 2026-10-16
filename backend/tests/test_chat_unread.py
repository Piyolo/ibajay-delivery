"""GET /chats/my and GET /chats/vendor `unread_count` (chat badge parity).

No database: a stub session answers each query the thread-listing path makes
(user lookup, chats, vendors, customers) so the assertions run against the
real route code, including `_thread_payloads`.

Badge semantics mirror the client (customer_app chat.dart): a message counts
as unread iff `not is_read and sender_id != requester_id` — `is_read` is a
single SHARED flag, so the same formula serves both sides.
"""
import uuid
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.core.db import get_db
from app.core.security import create_access_token
from app.main import app
from app.models.enums import UserRole
from app.models.social import Chat, Message

client = TestClient(app)

API = "/api/v1"
BASE = datetime(2026, 10, 16, 8, 0, tzinfo=timezone.utc)


class _Result:
    def __init__(self, one=None, rows=None):
        self._one = one
        self._rows = rows or []

    def scalar_one_or_none(self):
        return self._one

    def scalars(self):
        return self

    def unique(self):
        return self

    def all(self):
        return self._rows

    def first(self):
        return self._rows[0] if self._rows else None


class _User:
    def __init__(self, role=UserRole.customer):
        self.id = uuid.uuid4()
        self.full_name = "Juan Dela Cruz"
        self.mobile_number = "09171234567"
        self.email = "juan@example.com"
        self.role = role
        self.is_active = True
        self.is_email_verified = True
        self.token_version = 0


class _ChatDb:
    """Stub session that routes each query the thread endpoints issue."""

    def __init__(self, *, me, chats, vendors, customers, store):
        self.me = me
        self.chats = chats
        self.vendors = vendors  # id -> payload-side vendor
        self.customers = customers  # id -> payload-side customer
        self.store = store  # the requester's own store (vendor_threads step)

    async def execute(self, stmt, *args, **kwargs):
        sql = str(stmt)
        if "FROM chats" in sql:
            return _Result(rows=self.chats)
        if "FROM vendors" in sql:
            if " IN " in sql:  # _thread_payloads batch lookup
                return _Result(rows=list(self.vendors.values()))
            return _Result(one=self.store)  # owner's store
        if "FROM users" in sql:
            if " IN " in sql:  # _thread_payloads batch lookup
                return _Result(rows=list(self.customers.values()))
            return _Result(one=self.me)  # auth lookup
        raise AssertionError(f"unexpected query in chat unread test: {sql}")

    async def commit(self):
        pass

    async def close(self):
        pass


def _install(db):
    async def _override():
        yield db

    app.dependency_overrides[get_db] = _override


def _auth(user: _User) -> dict:
    token = create_access_token(str(user.id), user.role.value, user.token_version)
    return {"Authorization": f"Bearer {token}"}


def _message(sender_id: uuid.UUID, *, is_read: bool, seq: int) -> Message:
    return Message(
        id=uuid.uuid4(),
        chat_id=uuid.uuid4(),
        sender_id=sender_id,
        content=f"msg {seq}",
        is_read=is_read,
        created_at=BASE + timedelta(minutes=seq),
    )


def _seed(
    *,
    requester: _User,
    customer_id: uuid.UUID,
    vendor_id: uuid.UUID,
    owner_id: uuid.UUID,
    messages: list[Message],
):
    """Build one chat plus the payload-side vendor/customer/user rows."""
    chat = Chat(
        id=uuid.uuid4(),
        customer_id=customer_id,
        vendor_id=vendor_id,
        order_id=None,
        created_at=BASE,
        messages=messages,
    )
    vendor = SimpleNamespace(
        id=vendor_id, owner_id=owner_id, store_name="Luto ni Aling Susing", logo_url=None
    )
    customer = SimpleNamespace(
        id=customer_id, full_name="Juan Dela Cruz", mobile_number="09171234567"
    )
    db = _ChatDb(
        me=requester,
        chats=[chat],
        vendors={vendor_id: vendor},
        customers={customer_id: customer},
        store=vendor,
    )
    return db


def test_my_threads_unread_count_counts_only_vendor_unread_messages():
    customer = _User()
    owner = _User(role=UserRole.vendor)
    vendor_id = uuid.uuid4()
    messages = [
        _message(owner.id, is_read=False, seq=1),  # unread, from vendor -> counts
        _message(owner.id, is_read=False, seq=2),  # unread, from vendor -> counts
        _message(owner.id, is_read=True, seq=3),  # read, from vendor -> no
        _message(customer.id, is_read=False, seq=4),  # customer's own -> no
    ]
    db = _seed(
        requester=customer,
        customer_id=customer.id,
        vendor_id=vendor_id,
        owner_id=owner.id,
        messages=messages,
    )
    _install(db)
    try:
        resp = client.get(f"{API}/chats/my", headers=_auth(customer))
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 200, resp.text
    rows = resp.json()
    assert len(rows) == 1
    row = rows[0]
    assert "unread_count" in row  # contract key is snake_case and always present
    assert isinstance(row["unread_count"], int)
    assert row["unread_count"] == 2  # 2 vendor-unread; read + own message excluded
    assert row["message_count"] == 4


def test_vendor_threads_unread_count_counts_only_customer_unread_messages():
    vendor_user = _User(role=UserRole.vendor)
    customer = _User()
    vendor_id = uuid.uuid4()
    messages = [
        _message(customer.id, is_read=False, seq=1),  # unread, from customer -> counts
        _message(customer.id, is_read=False, seq=2),  # unread, from customer -> counts
        _message(customer.id, is_read=True, seq=3),  # read, from customer -> no
        _message(vendor_user.id, is_read=False, seq=4),  # vendor's own -> no
    ]
    db = _seed(
        requester=vendor_user,
        customer_id=customer.id,
        vendor_id=vendor_id,
        owner_id=vendor_user.id,
        messages=messages,
    )
    _install(db)
    try:
        resp = client.get(f"{API}/chats/vendor", headers=_auth(vendor_user))
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 200, resp.text
    rows = resp.json()
    assert len(rows) == 1
    row = rows[0]
    assert "unread_count" in row
    assert row["unread_count"] == 2  # own unread vendor message never counts


def test_customer_owned_messages_never_count_even_when_unread():
    customer = _User()
    owner = _User(role=UserRole.vendor)
    vendor_id = uuid.uuid4()
    # Every message is unread (is_read=False) but all belong to the customer:
    # a thread the customer never heard back in still shows badge 0.
    messages = [
        _message(customer.id, is_read=False, seq=1),
        _message(customer.id, is_read=False, seq=2),
    ]
    db = _seed(
        requester=customer,
        customer_id=customer.id,
        vendor_id=vendor_id,
        owner_id=owner.id,
        messages=messages,
    )
    _install(db)
    try:
        resp = client.get(f"{API}/chats/my", headers=_auth(customer))
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 200, resp.text
    rows = resp.json()
    assert len(rows) == 1
    assert rows[0]["unread_count"] == 0
    assert rows[0]["message_count"] == 2
