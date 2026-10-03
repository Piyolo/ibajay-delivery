"""add barangay to addresses

Revision ID: 002_add_barangay_addresses
Revises: 001_add_discount_promotion
Create Date: 2026-10-03
"""
from alembic import op

revision = "002_add_barangay_addresses"
down_revision = "001_add_discount_promotion"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        ALTER TABLE addresses
            ADD COLUMN IF NOT EXISTS barangay VARCHAR(100) NOT NULL DEFAULT ''
    """)


def downgrade() -> None:
    op.execute("ALTER TABLE addresses DROP COLUMN IF EXISTS barangay")
