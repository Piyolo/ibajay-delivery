-- ============================================================
-- One-shot patch: add discount + promotion_id to orders table
-- Run this directly in your Neon/Supabase SQL console if you
-- don't want to run Alembic.
-- Safe to re-run (uses IF NOT EXISTS / IF EXISTS).
-- ============================================================

-- Step 1: ensure promotions table exists (created by app model,
--         but may be missing if the DB was seeded before the model was added)
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
);

-- Step 2: add missing columns to orders
ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS discount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS promotion_id UUID REFERENCES promotions(id) ON DELETE SET NULL;

-- Verify
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'orders'
  AND column_name IN ('discount', 'promotion_id')
ORDER BY column_name;
