-- One-shot migration: promotions + order discounts.
-- Run once against the existing Neon database (psql / Neon SQL editor).
-- Fresh databases created via create_tables.py already include these.

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
    times_used INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE orders ADD COLUMN IF NOT EXISTS discount NUMERIC(10, 2) NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS promotion_id UUID REFERENCES promotions(id) ON DELETE SET NULL;

-- Addresses.barangay (per-user delivery-area matching)
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS barangay VARCHAR(100) NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS ix_promotions_vendor ON promotions(vendor_id);
