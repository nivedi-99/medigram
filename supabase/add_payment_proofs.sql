-- ===========================================================================
-- MediGram upgrade: buyer payment proofs (post-payment screenshots)
-- Safe to re-run. Apply via the Supabase SQL Editor, or from backend/:
--   node scripts/run-sql.mjs ../supabase/add_payment_proofs.sql
--
-- Adds:
--   storage bucket
--     'payment-proofs'       — public-read bucket the API uploads buyer
--                              payment screenshots to
--                              (backend POST /api/v1/uploads/payment-proof).
-- ===========================================================================

-- 1. Storage bucket for payment screenshots — public so the buyer and the
--    trade desk can render the uploaded proof directly from the public URL
--    returned by the upload endpoint.
insert into storage.buckets (id, name, public)
values ('payment-proofs', 'payment-proofs', true)
on conflict (id) do update set public = true;

-- 2. Public read policy (defense in depth; public buckets are readable, but
--    keep an explicit policy so access survives bucket-flag changes).
drop policy if exists "Public read payment proofs" on storage.objects;
create policy "Public read payment proofs"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'payment-proofs');

-- 3. Signed-in buyers may add their own screenshots (belt & braces — the API
--    uploads with the service-role key, so this only covers direct Supabase
--    access from the client SDK; objects are namespaced per user folder).
drop policy if exists "Buyers write own payment proofs" on storage.objects;
create policy "Buyers write own payment proofs"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'payment-proofs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
