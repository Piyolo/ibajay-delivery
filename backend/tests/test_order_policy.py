"""DB-free tests for the checkout hardening added in the beta round 3:

- CheckoutRequest/CartItemIn validation (quantity bounds, cart size,
  past scheduled_for, instruction lengths) — the ₱0-order / overflow bugs.
- NEXT_STATUS map + cancellation policy (can_cancel_order).
- _promo_discount clamping / validity helpers.
- Manila-day bucketing helpers.
"""
from datetime import datetime, timedelta, timezone
import uuid

import pytest
from pydantic import ValidationError

from app.core.manila_time import manila_date, manila_day_start_utc
from app.models.enums import DeliveryMethod, OrderStatus, PaymentMethod
from app.routers.orders import (
    IDEMPOTENCY_KEY_TTL,
    NEXT_STATUS,
    VENDOR_CANCELLABLE,
    _promo_discount,
    _promo_is_live,
    can_cancel_order,
)
from app.schemas.order import (
    MAX_CART_ITEMS,
    MAX_QUANTITY,
    CartItemIn,
    CheckoutRequest,
    UpdateOrderStatus,
)


def _checkout_payload(**overrides):
    base = {
        "vendor_id": uuid.uuid4(),
        "items": [{"food_item_id": uuid.uuid4(), "quantity": 1}],
        "delivery_method": DeliveryMethod.pickup,
        "payment_method": PaymentMethod.cash_on_delivery,  # any member value
    }
    base.update(overrides)
    return base


class TestQuantityValidation:
    def test_zero_quantity_rejected(self):
        with pytest.raises(ValidationError):
            CartItemIn(food_item_id=uuid.uuid4(), quantity=0)

    def test_negative_quantity_rejected(self):
        with pytest.raises(ValidationError):
            # The beta bug: quantity=-5 priced a payable ₱0 order.
            CartItemIn(food_item_id=uuid.uuid4(), quantity=-5)

    def test_extreme_quantity_rejected(self):
        with pytest.raises(ValidationError):
            # 2_147_483_647+ previously reached Postgres as int4 overflow -> 500.
            CartItemIn(food_item_id=uuid.uuid4(), quantity=2_147_483_647)

    def test_quantity_cap_is_reasonable(self):
        assert MAX_QUANTITY == 99
        with pytest.raises(ValidationError):
            CartItemIn(food_item_id=uuid.uuid4(), quantity=100)

    def test_valid_quantity_accepted(self):
        assert CartItemIn(food_item_id=uuid.uuid4(), quantity=3).quantity == 3

    def test_default_quantity_is_one(self):
        assert CartItemIn(food_item_id=uuid.uuid4()).quantity == 1


class TestCheckoutValidation:
    def test_empty_items_allowed_at_schema_level(self):
        # The friendly "Cart cannot be empty" 400 lives in the route; the
        # schema doesn't impose min_length so checkout validation errors
        # keep their existing response contract.
        payload = CheckoutRequest(**_checkout_payload(items=[]))
        assert payload.items == []

    def test_cart_size_capped(self):
        with pytest.raises(ValidationError):
            CheckoutRequest(
                **_checkout_payload(
                    items=[
                        {"food_item_id": uuid.uuid4(), "quantity": 1}
                        for _ in range(MAX_CART_ITEMS + 1)
                    ]
                )
            )

    def test_past_scheduled_for_rejected(self):
        with pytest.raises(ValidationError):
            CheckoutRequest(
                **_checkout_payload(
                    scheduled_for=datetime.now(timezone.utc) - timedelta(hours=1)
                )
            )

    def test_future_scheduled_for_accepted(self):
        CheckoutRequest(
            **_checkout_payload(scheduled_for=datetime.now(timezone.utc) + timedelta(hours=1))
        )

    def test_delivery_without_address_rejected(self):
        with pytest.raises(ValidationError):
            CheckoutRequest(
                **_checkout_payload(delivery_method=DeliveryMethod.delivery, address_id=None)
            )

    def test_promo_code_length_capped(self):
        with pytest.raises(ValidationError):
            CheckoutRequest(**_checkout_payload(promo_code="X" * 41))


class TestStatusNoteValidation:
    def test_note_over_500_rejected(self):
        with pytest.raises(ValidationError):
            UpdateOrderStatus(status=OrderStatus.accepted, note="n" * 501)

    def test_note_up_to_500_ok(self):
        assert UpdateOrderStatus(status=OrderStatus.accepted, note="n" * 500).note == "n" * 500


class TestTransitionMap:
    def test_cancel_is_not_a_forward_transition(self):
        # Cancellation must go through /cancel (so a reason is recorded);
        # PATCH /status may only advance the order.
        for allowed in NEXT_STATUS.values():
            assert OrderStatus.cancelled not in allowed

    def test_full_delivery_progression_supported(self):
        chain = [
            (OrderStatus.pending, OrderStatus.accepted),
            (OrderStatus.accepted, OrderStatus.preparing),
            (OrderStatus.preparing, OrderStatus.ready),
            (OrderStatus.ready, OrderStatus.out_for_delivery),
            (OrderStatus.out_for_delivery, OrderStatus.delivered),
            (OrderStatus.delivered, OrderStatus.completed),
        ]
        for current, nxt in chain:
            assert nxt in NEXT_STATUS[current]


class TestCancellationPolicy:
    @pytest.mark.parametrize(
        "status",
        [OrderStatus.pending, OrderStatus.accepted],
    )
    def test_customer_can_cancel_early(self, status):
        assert can_cancel_order(status, is_customer=True)

    @pytest.mark.parametrize(
        "status",
        [
            OrderStatus.preparing,
            OrderStatus.ready,
            OrderStatus.out_for_delivery,
            OrderStatus.delivered,
            OrderStatus.completed,
            OrderStatus.cancelled,
        ],
    )
    def test_customer_cannot_cancel_once_preparation_starts(self, status):
        # Business plan §21: Preparing/Ready restricted, OFD onwards impossible.
        assert not can_cancel_order(status, is_customer=True)

    @pytest.mark.parametrize(
        "status",
        [
            OrderStatus.pending,
            OrderStatus.accepted,
            OrderStatus.preparing,
            OrderStatus.ready,
            OrderStatus.out_for_delivery,
        ],
    )
    def test_vendor_can_cancel_pre_delivery(self, status):
        assert can_cancel_order(status, is_customer=False)

    @pytest.mark.parametrize(
        "status",
        [OrderStatus.delivered, OrderStatus.completed, OrderStatus.cancelled],
    )
    def test_nobody_cancels_terminal_orders(self, status):
        assert not can_cancel_order(status, is_customer=False)

    def test_vendor_policy_covers_customer_unset_states(self):
        assert VENDOR_CANCELLABLE == {
            OrderStatus.pending,
            OrderStatus.accepted,
            OrderStatus.preparing,
            OrderStatus.ready,
            OrderStatus.out_for_delivery,
        }


class TestPromoHelpers:
    def test_percent_discount(self):
        promo = _promo()
        promo.discount_value = 10
        assert _promo_discount(promo, 200.0) == 20.0

    def test_fixed_discount(self):
        promo = _promo()
        promo.discount_type = "fixed"
        promo.discount_value = 50
        assert _promo_discount(promo, 200.0) == 50.0

    def test_discount_never_exceeds_subtotal(self):
        # Percent promotions never exceed 100% at the API now, but the
        # clamp is the final backstop for legacy rows.
        promo = _promo()
        promo.discount_value = 150
        assert _promo_discount(promo, 40.0) == 40.0

    def test_expired_promo_is_not_live(self):
        promo = _promo()
        promo.ends_at = datetime.now(timezone.utc) - timedelta(hours=1)
        assert _promo_is_live(promo, datetime.now(timezone.utc)) is False


def _promo():
    from app.models.social import Promotion

    promo = Promotion(vendor_id=uuid.uuid4(), title="t", discount_type="percent", discount_value=10)
    return promo


class TestManilaTime:
    def test_evening_order_buckets_on_same_manila_day(self):
        # 21:30 UTC = 05:30 PHT the NEXT day — the class of mis-bucketing
        # that put evening Manila orders into the wrong analytics day.
        instant = datetime(2026, 10, 16, 21, 30, tzinfo=timezone.utc)
        assert manila_date(instant) == datetime(2026, 10, 17).date()

    def test_day_start_conversion_is_inverse(self):
        day = datetime(2026, 10, 16).date()
        start_utc = manila_day_start_utc(day)
        assert manila_date(start_utc) == day
        assert start_utc.hour == 16  # 00:00 PHT = 16:00 UTC prior day

    def test_idempotency_ttl_is_one_day(self):
        assert IDEMPOTENCY_KEY_TTL == timedelta(hours=24)
