-- ============================================================
-- Migration 005 — Rename subscription product IDs to match
--                 RevenueCat / App Store product identifiers.
-- Old: gfm_weekly / gfm_monthly / gfm_yearly
-- New: GFM_Weekly_3.99 / GFM_Monthly_4.99 / GFM_Yearly_44.99
-- ============================================================

-- ── UP ────────────────────────────────────────────────────────────────────────

-- 1. Insert new rows copying quota_amount from the old rows
INSERT INTO quota_products (product_id, product_type, display_name, quota_amount, updated_at)
SELECT 'GFM_Weekly_3.99',  product_type, 'Weekly Premium',  quota_amount, NOW()
FROM   quota_products WHERE product_id = 'gfm_weekly'
ON CONFLICT (product_id) DO NOTHING;

INSERT INTO quota_products (product_id, product_type, display_name, quota_amount, updated_at)
SELECT 'GFM_Monthly_4.99', product_type, 'Monthly Premium', quota_amount, NOW()
FROM   quota_products WHERE product_id = 'gfm_monthly'
ON CONFLICT (product_id) DO NOTHING;

INSERT INTO quota_products (product_id, product_type, display_name, quota_amount, updated_at)
SELECT 'GFM_Yearly_44.99', product_type, 'Yearly Premium',  quota_amount, NOW()
FROM   quota_products WHERE product_id = 'gfm_yearly'
ON CONFLICT (product_id) DO NOTHING;

-- 2. Re-point any existing quota_transactions to the new product IDs
UPDATE quota_transactions SET product_id = 'GFM_Weekly_3.99'  WHERE product_id = 'gfm_weekly';
UPDATE quota_transactions SET product_id = 'GFM_Monthly_4.99' WHERE product_id = 'gfm_monthly';
UPDATE quota_transactions SET product_id = 'GFM_Yearly_44.99' WHERE product_id = 'gfm_yearly';

-- 3. Re-point any users whose subscription_product_id still uses old IDs
UPDATE users SET subscription_product_id = 'GFM_Weekly_3.99'  WHERE subscription_product_id = 'gfm_weekly';
UPDATE users SET subscription_product_id = 'GFM_Monthly_4.99' WHERE subscription_product_id = 'gfm_monthly';
UPDATE users SET subscription_product_id = 'GFM_Yearly_44.99' WHERE subscription_product_id = 'gfm_yearly';

-- 4. Remove old rows
DELETE FROM quota_products WHERE product_id IN ('gfm_weekly', 'gfm_monthly', 'gfm_yearly');


-- ── DOWN ──────────────────────────────────────────────────────────────────────

-- INSERT INTO quota_products (product_id, product_type, display_name, quota_amount, updated_at)
-- SELECT 'gfm_weekly',  product_type, 'Weekly Premium',  quota_amount, NOW() FROM quota_products WHERE product_id = 'GFM_Weekly_3.99'  ON CONFLICT DO NOTHING;
-- INSERT INTO quota_products (product_id, product_type, display_name, quota_amount, updated_at)
-- SELECT 'gfm_monthly', product_type, 'Monthly Premium', quota_amount, NOW() FROM quota_products WHERE product_id = 'GFM_Monthly_4.99' ON CONFLICT DO NOTHING;
-- INSERT INTO quota_products (product_id, product_type, display_name, quota_amount, updated_at)
-- SELECT 'gfm_yearly',  product_type, 'Yearly Premium',  quota_amount, NOW() FROM quota_products WHERE product_id = 'GFM_Yearly_44.99' ON CONFLICT DO NOTHING;
-- UPDATE quota_transactions SET product_id = 'gfm_weekly'  WHERE product_id = 'GFM_Weekly_3.99';
-- UPDATE quota_transactions SET product_id = 'gfm_monthly' WHERE product_id = 'GFM_Monthly_4.99';
-- UPDATE quota_transactions SET product_id = 'gfm_yearly'  WHERE product_id = 'GFM_Yearly_44.99';
-- UPDATE users SET subscription_product_id = 'gfm_weekly'  WHERE subscription_product_id = 'GFM_Weekly_3.99';
-- UPDATE users SET subscription_product_id = 'gfm_monthly' WHERE subscription_product_id = 'GFM_Monthly_4.99';
-- UPDATE users SET subscription_product_id = 'gfm_yearly'  WHERE subscription_product_id = 'GFM_Yearly_44.99';
-- DELETE FROM quota_products WHERE product_id IN ('GFM_Weekly_3.99', 'GFM_Monthly_4.99', 'GFM_Yearly_44.99');
