"""Add-on pricing at checkout (the "Add-ons doesn't compute on totals" bug).

No database: a stub session answers each query the checkout path makes and
captures whatever gets added, so the assertions run against the real route
code (server-side price lookup, line totals, subtotal, grand total).
"""
import uuid
from datetime import datetime, timezone
from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.core.db import get_db
from app.core.security import create_access_token
from app.main import app
from app.models.enums import NotificationType, UserRole
from app.models.social import Notification

client = TestClient(app)

API = "/api/v1"


class _Result:
    def __init__(self, one=None, all_rows=None, rowcount=0):
        self._one = one
        self._all = all_rows or []
        self.rowcount = rowcount

    def scalar_one_or_none(self):
        return self._one

    def scalars(self):
        return self

    def unique(self):
        return self

    def all(self):
        return self._all

    def first(self):
        return self._all[0] if self._all else None


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


def _vendor(vendor_id: uuid.UUID) -> SimpleNamespace:
    return SimpleNamespace(
        id=vendor_id,
        owner_id=uuid.uuid4(),
        is_paused=False,
        is_open=True,
        latitude=0.0,
        longitude=0.0,
        delivery_settings=SimpleNamespace(
            pickup_enabled=True,
            delivery_enabled=True,
            scheduled_delivery_enabled=True,
            delivery_radius_km=99,
            base_delivery_fee=0,
            fee_per_km=0,
            delivery_barangays=[],
        ),
    )


def _food(food_id: uuid.UUID, vendor_id: uuid.UUID, price: float) -> SimpleNamespace:
    return SimpleNamespace(
        id=food_id,
        vendor_id=vendor_id,
        name="Sisig Rice",
        price=price,
        is_available=True,
    )


def _fill_defaults(obj) -> None:
    """Mimic the Python-side column defaults a real flush would apply."""
    now = datetime.now(timezone.utc)
    if getattr(obj, "id", None) is None:
        obj.id = uuid.uuid4()
    if getattr(obj, "created_at", None) is None:
        obj.created_at = now
    if hasattr(obj, "discount") and obj.discount is None:
        obj.discount = 0
    if hasattr(obj, "is_read") and obj.is_read is None:
        obj.is_read = False
    for item in getattr(obj, "items", None) or []:
        if item.id is None:
            item.id = uuid.uuid4()


class _CheckoutDb:
    """Dispatches checkout queries on the compiled SQL and records writes."""

    def __init__(self, user, vendor, food, option_rows):
        self.user = user
        self.vendor = vendor
        self.food = food
        self.option_rows = option_rows
        self.added = []
        self.commits = 0
        self.rolled_back = False

    async def execute(self, stmt, *args, **kwargs):
        sql = str(stmt)
        if "FROM users" in sql:
            return _Result(one=self.user)
        if "FROM vendors" in sql:
            return _Result(one=self.vendor)
        if "FROM food_items" in sql:
            return _Result(one=self.food)
        if "FROM food_options" in sql:
            return _Result(all_rows=list(self.option_rows))
        raise AssertionError(f"unexpected query in checkout test: {sql}")

    def add(self, obj):
        self.added.append(obj)

    async def flush(self):
        for obj in self.added:
            _fill_defaults(obj)

    async def commit(self):
        self.commits += 1

    async def rollback(self):
        self.rolled_back = True

    async def refresh(self, obj, attribute_names=None):
        _fill_defaults(obj)

    async def close(self):
        pass


def _install(db: _CheckoutDb):
    async def _override():
        yield db

    app.dependency_overrides[get_db] = _override


def _checkout_body(food_id: uuid.UUID, vendor_id: uuid.UUID, selected_options: dict) -> dict:
    return {
        "vendor_id": str(vendor_id),
        "delivery_method": "pickup",
        "payment_method": "cash_on_pickup",
        "items": [
            {
                "food_item_id": str(food_id),
                "quantity": 2,
                "selected_options": selected_options,
            }
        ],
    }


def _place(db: _CheckoutDb, food_id: uuid.UUID, vendor_id: uuid.UUID, selected_options: dict, user: _Customer):
    token = create_access_token(str(user.id), "customer", user.token_version)
    return client.post(
        f"{API}/orders/checkout",
        json=_checkout_body(food_id, vendor_id, selected_options),
        headers={"Authorization": f"Bearer {token}"},
    )


def test_checkout_totals_include_addon_choice_prices():
    user = _Customer()
    vendor_id, food_id = uuid.uuid4(), uuid.uuid4()
    # base 100 + (25 + 25 add-ons) = 150/unit, qty 2 -> 300 line/subtotal/total
    db = _CheckoutDb(
        user=user,
        vendor=_vendor(vendor_id),
        food=_food(food_id, vendor_id, price=100),
        option_rows=[("Extras", "Add Cheese", 25), ("Extras", "Add Bacon", 25)],
    )
    _install(db)
    try:
        resp = _place(db, food_id, vendor_id, {"Extras": ["Add Cheese", "Add Bacon"]}, user)
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 201, resp.text
    body = resp.json()
    item = body["items"][0]
    assert item["unit_price"] == 150  # base + per-unit add-ons
    assert item["line_total"] == 300  # unit_price * quantity
    assert body["subtotal"] == 300
    assert body["total"] == 300  # pickup: no fee, no discount
    # checkout still notifies the vendor (persisted, not just printed)
    notes = [a for a in db.added if isinstance(a, Notification)]
    assert len(notes) == 1
    assert notes[0].type == NotificationType.new_order
    assert notes[0].related_order_id is not None


def test_checkout_ignores_labels_that_do_not_exist_on_the_food_item():
    """Client-supplied labels are never priced: only server rows count."""
    user = _Customer()
    vendor_id, food_id = uuid.uuid4(), uuid.uuid4()
    db = _CheckoutDb(
        user=user,
        vendor=_vendor(vendor_id),
        food=_food(food_id, vendor_id, price=100),
        option_rows=[("Extras", "Add Cheese", 25)],
    )
    _install(db)
    try:
        resp = _place(db, food_id, vendor_id, {"Extras": ["Free Money"]}, user)
    finally:
        app.dependency_overrides.clear()

    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["items"][0]["unit_price"] == 100
    assert body["items"][0]["line_total"] == 200
    assert body["subtotal"] == 200
    assert body["total"] == 200
