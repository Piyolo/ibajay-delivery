"""add 'order_cancelled' to the notificationtype enum

The notifications.type column is a native Postgres enum (created from
NotificationType by Base.metadata.create_all), so the new order-cancelled
notification can only be inserted after the label exists in the type.

Revision ID: 004_cancelled_notification
Revises: 003_add_token_version
Create Date: 2026-10-13

Note: revision IDs must stay under 32 chars — alembic_version.version_num
is VARCHAR(32) in this database.
"""
from alembic import op

revision = "004_cancelled_notification"
down_revision = "003_add_token_version"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # IF NOT EXISTS keeps this idempotent against fresh databases where
    # create_all already built the enum from the model's full value list.
    # (PostgreSQL >= 12 allows ADD VALUE inside the migration transaction;
    # the new label is only *used* by later inserts, after commit.)
    op.execute("ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'order_cancelled'")


def downgrade() -> None:
    # PostgreSQL has no ALTER TYPE ... DROP VALUE. Leaving the label in
    # place is harmless: nothing inserts it once the model no longer
    # defines it. Recreating the type would require rewriting the column
    # and is not worth the risk on a live table.
    pass
