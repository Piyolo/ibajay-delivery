"""add token_version to users

Revision ID: 003_add_token_version
Revises: 002_add_barangay_addresses
Create Date: 2026-10-13
"""
from alembic import op

revision = "003_add_token_version"
down_revision = "002_add_barangay_addresses"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Backfills existing rows with 0 (NOT NULL + DEFAULT), matching the
    # User model's server_default. IF NOT EXISTS keeps it idempotent with
    # Base.metadata.create_all (which never alters existing tables).
    op.execute("""
        ALTER TABLE users
            ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 0
    """)


def downgrade() -> None:
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS token_version")
