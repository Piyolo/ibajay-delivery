"""hot-path FK indexes + checkout idempotency table

The beta's list endpoints (my-orders, vendor inbox, notifications, chat
threads, menu lookups) all filter on FK columns that previously had no
indexes — Postgres does NOT auto-index foreign keys — so every one of those
queries full-scanned. This migration adds the btree indexes on the columns
the apps actually filter, plus the checkout_idempotency_keys table that
backs POST /orders/checkout replay (duplicate-submission protection).

idempotent everywhere: raw IF NOT EXISTS SQL, so it is safe to run on a
database where the app already came up (Base.metadata.create_all in
main.lifespan creates the table and the model-level indexes first — the
then-unknown alembic_head state is handled like migration 004).

Note: revision IDs must stay under 32 chars — alembic_version.version_num
is VARCHAR(32) in this database.

Revision ID: 005_hot_indexes
Revises: 004_cancelled_notification
Create Date: 2026-10-16
"""
from alembic import op

revision = "005_hot_indexes"
down_revision = "004_cancelled_notification"
branch_labels = None
depends_on = None

_INDEXES = [
    ("orders", "customer_id"),
    ("orders", "vendor_id"),
    ("orders", "status"),
    ("order_items", "order_id"),
    ("order_status_history", "order_id"),
    ("chats", "customer_id"),
    ("chats", "vendor_id"),
    ("messages", "chat_id"),
    ("notifications", "user_id"),
    ("food_items", "vendor_id"),
    ("addresses", "user_id"),
]


def upgrade() -> None:
    # Creates the table when alembic runs BEFORE the app deployed it, and
    # no-ops when create_all already did. Column/constraint names mirror the
    # CheckoutIdempotencyKey model exactly.
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS checkout_idempotency_keys (
            id UUID PRIMARY KEY,
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            key VARCHAR(72) NOT NULL,
            order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
            CONSTRAINT uq_checkout_key_user_id_key UNIQUE (user_id, key)
        )
        """
    )

    # Same names SQLAlchemy's default naming convention generates from the
    # models, so the app and this migration converge on the same schema.
    for table, column in _INDEXES:
        op.execute(f'CREATE INDEX IF NOT EXISTS "ix_{table}_{column}" ON "{table}" ("{column}")')


def downgrade() -> None:
    for table, column in reversed(_INDEXES):
        op.execute(f'DROP INDEX IF EXISTS "ix_{table}_{column}"')
    op.execute("DROP TABLE IF EXISTS checkout_idempotency_keys")
