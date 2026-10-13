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

-- ---------------------------------------------------------------------------
-- 4. payment_proofs — persisted record for every uploaded screenshot so the
--    trade desk can review and verify INR payments
--    (status: pending | verified | rejected). The API inserts the row with
--    the service-role key after a successful upload; buyers can read their
--    own rows directly.
-- ---------------------------------------------------------------------------
create table if not exists public.payment_proofs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null,
  url        text not null,
  amount_inr numeric(14, 2) check (amount_inr is null or amount_inr >= 0),
  reference  text not null default '',
  order_id   uuid,
  status     text not null default 'pending',
  created_at timestamptz not null default now()
);

create index if not exists payment_proofs_user_idx
  on public.payment_proofs (user_id, created_at desc);

alter table public.payment_proofs enable row level security;

drop policy if exists "Buyers read own payment proofs" on public.payment_proofs;
create policy "Buyers read own payment proofs"
  on public.payment_proofs for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "Buyers insert own payment proofs" on public.payment_proofs;
create policy "Buyers insert own payment proofs"
  on public.payment_proofs for insert
  to authenticated
  with check (user_id = auth.uid());
