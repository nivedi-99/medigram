-- ===========================================================================
-- MediGram upgrade: product strength + order payment status
-- Safe to re-run. Apply via the Supabase SQL Editor, or from backend/:
--   node scripts/run-sql.mjs ../supabase/upgrade_strength_payments.sql
-- ===========================================================================

-- 1. Products: free-text strength (e.g. 500 mg, 250mg/5ml).
alter table public.products
  add column if not exists strength text not null default '';

-- 2. Orders: payment tracking for invoices (pending | paid).
alter table public.orders
  add column if not exists payment_status text not null default 'pending';
