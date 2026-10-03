"""add discount and promotion_id to orders, create promotions table

Revision ID: 001_add_discount_promotion
Revises: 
Create Date: 2026-09-19
"""
from alembic import op

revision = "001_add_discount_promotion"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Create promotions table if not exists
    op.execute("""
        CREATE TABLE IF NOT EXISTS promotions (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
            title VARCHAR(120) NOT NULL,
            description VARCHAR(500),
            discount_type VARCHAR(10) NOT NULL DEFAULT 'percent',
            discount_value NUMERIC(10, 2) NOT NULL,
            code VARCHAR(40),
            min_subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0,
            starts_at TIMESTAMPTZ,
            ends_at TIMESTAMPTZ,
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            times_used INTEGER NOT NULL DEFAULT 0,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
    """)

    # 2. Add missing columns to orders (idempotent with IF NOT EXISTS)
    op.execute("""
        ALTER TABLE orders
            ADD COLUMN IF NOT EXISTS discount NUMERIC(10, 2) NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS promotion_id UUID REFERENCES promotions(id) ON DELETE SET NULL
    """)


def downgrade() -> None:
    op.execute("ALTER TABLE orders DROP COLUMN IF EXISTS promotion_id")
    op.execute("ALTER TABLE orders DROP COLUMN IF EXISTS discount")
