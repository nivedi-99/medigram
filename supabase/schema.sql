-- ============================================================================
-- MediGram — Global Pharmaceutical Export Platform (B2B)
-- Schema v1.1 — database layer of the bottom-up build (M1)
--
-- Tables : profiles, client_profiles, admin_handlers, products, orders,
--          order_items, notifications
-- Safety : Row Level Security everywhere, role changes only via guarded RPCs
-- Pipes : handle_new_user (signup), check_order_client_verified,
--          recalc_order_total, trg_order_notify, trg_kyc_notify
--
-- HOW TO APPLY
--   Supabase dashboard → SQL Editor → New query → paste ALL → Run.
--   Then run supabase/verify.sql — every check must print PASSED.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0. Extensions
-- ---------------------------------------------------------------------------
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. Enumerated types (CREATE TYPE has no IF NOT EXISTS → DO blocks)
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.user_role as enum ('client', 'admin', 'super_admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.order_status as enum ('processing', 'shipped', 'delivered', 'cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.notification_kind as enum ('order', 'kyc', 'system');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- 2. Profiles — one row per auth user (auto-created by trigger)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  email        text not null,
  full_name    text not null default '',
  phone        text not null default '',
  role         public.user_role not null default 'client',
  company_name text not null default '',
  country      text not null default '',
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.profiles is 'Core user record; role drives routing (client/admin/super_admin).';

-- ---------------------------------------------------------------------------
-- 3. Client database — extended B2B data for role = client
-- ---------------------------------------------------------------------------
create table if not exists public.client_profiles (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null unique references public.profiles (id) on delete cascade,
  company_name        text not null default '',
  country             text not null default '',
  business_license_no text not null default '',
  import_permit_no    text not null default '',
  tax_id              text not null default '',
  verification_status text not null default 'pending'
                      check (verification_status in ('pending', 'verified', 'rejected')),
  verified_at         timestamptz,
  assigned_admin_id   uuid references public.profiles (id) on delete set null,
  contact_email       text not null default '',
  contact_phone       text not null default '',
  created_at          timestamptz not null default now()
);

comment on table public.client_profiles is 'B2B client records: licences, KYC status, assigned admin handler.';

-- ---------------------------------------------------------------------------
-- 4. Admin handlers — staff managing clients & orders
-- ---------------------------------------------------------------------------
create table if not exists public.admin_handlers (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null unique references public.profiles (id) on delete cascade,
  full_name   text not null default '',
  email       text not null default '',
  department  text not null default 'Client Servicing',
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

comment on table public.admin_handlers is 'Admin staff registry managed by super admins.';

-- ---------------------------------------------------------------------------
-- 5. Products — the export catalogue
-- ---------------------------------------------------------------------------
create table if not exists public.products (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  category      text not null default 'General',
  manufacturer  text not null default '',
  description   text not null default '',
  strength      text not null default '',
  price         numeric(12, 2) not null default 0 check (price >= 0),
  currency      text not null default 'USD',
  min_order_qty integer not null default 1 check (min_order_qty > 0),
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 6. Orders — export orders placed by verified clients
-- ---------------------------------------------------------------------------
create sequence if not exists public.order_number_seq start 10001;

create table if not exists public.orders (
  id               uuid primary key default gen_random_uuid(),
  order_number     text unique not null
                   default ('MG-' || nextval('public.order_number_seq')::text),
  client_user_id   uuid not null references public.profiles (id) on delete cascade,
  status           public.order_status not null default 'processing',
  total_amount     numeric(14, 2) not null default 0 check (total_amount >= 0),
  currency         text not null default 'USD',
  incoterms        text not null default 'FOB',
  payment_method   text not null default 'Wire Transfer',
  payment_status   text not null default 'pending',
  shipping_address text not null default '',
  notes            text not null default '',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table if not exists public.order_items (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references public.orders (id) on delete cascade,
  product_id   uuid references public.products (id) on delete set null,
  product_name text not null,
  quantity     integer not null default 1 check (quantity > 0),
  unit_price   numeric(12, 2) not null default 0 check (unit_price >= 0),
  -- Server-computed line total; never trusted from the client.
  line_total   numeric(14, 2) generated always as (quantity::numeric * unit_price) stored
);

-- ---------------------------------------------------------------------------
-- 7. Notifications — per-user inbox fed by DB triggers (data pipelines)
-- ---------------------------------------------------------------------------
create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  title      text not null,
  body       text not null default '',
  kind       public.notification_kind not null default 'system',
  is_read    boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);

create index if not exists orders_client_idx on public.orders (client_user_id);
create index if not exists order_items_order_idx on public.order_items (order_id);
create index if not exists client_profiles_status_idx on public.client_profiles (verification_status);

-- ---------------------------------------------------------------------------
-- 8. PIPELINE: signup — auto-create a profile for every new auth user
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, phone, company_name, country)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce(new.raw_user_meta_data ->> 'company_name', ''),
    coalesce(new.raw_user_meta_data ->> 'country', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 9. PIPELINE: order integrity — only verified clients may place orders
-- ---------------------------------------------------------------------------
create or replace function public.check_order_client_verified()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if not exists (
    select 1 from public.client_profiles c
    where c.user_id = new.client_user_id
      and c.verification_status = 'verified'
  ) then
    raise exception 'ORDER_REQUIRES_VERIFIED_CLIENT';
  end if;
  return new;
end;
$$;

drop trigger if exists orders_check_verified on public.orders;
create trigger orders_check_verified
  before insert on public.orders
  for each row execute function public.check_order_client_verified();

-- ---------------------------------------------------------------------------
-- 10. PIPELINE: totals — keep orders.total_amount in sync with line items
-- ---------------------------------------------------------------------------
create or replace function public.recalc_order_total()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  target_order uuid;
begin
  target_order := coalesce(new.order_id, old.order_id);
  update public.orders o
     set total_amount = coalesce(
       (select sum(i.line_total) from public.order_items i where i.order_id = target_order),
       0)
   where o.id = target_order;
  return null;
end;
$$;

drop trigger if exists order_items_recalc on public.order_items;
create trigger order_items_recalc
  after insert or update or delete on public.order_items
  for each row execute function public.recalc_order_total();

-- ---------------------------------------------------------------------------
-- 11. PIPELINE: fulfilment — notify the client on status change
-- ---------------------------------------------------------------------------
create or replace function public.trg_order_notify()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status is distinct from old.status then
    insert into public.notifications (user_id, title, body, kind)
    values (
      new.client_user_id,
      'Order ' || new.order_number || ' — ' || new.status,
      case new.status
        when 'processing' then 'Your export order has been received and is being processed.'
        when 'shipped'    then 'Your order has been shipped and is on its way.'
        when 'delivered'  then 'Your order was delivered. We hope everything arrived perfectly.'
        when 'cancelled'  then 'Your order was cancelled. Contact your handler for details.'
      end,
      'order'
    );
  end if;
  return null;
end;
$$;

drop trigger if exists orders_status_notify on public.orders;
create trigger orders_status_notify
  after update on public.orders
  for each row execute function public.trg_order_notify();

-- ---------------------------------------------------------------------------
-- 12. PIPELINE: KYC — notify the client when verification changes
-- ---------------------------------------------------------------------------
create or replace function public.trg_kyc_notify()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.verification_status is distinct from old.verification_status then
    insert into public.notifications (user_id, title, body, kind)
    values (
      new.user_id,
      case new.verification_status
        when 'verified' then 'Business account verified'
        when 'rejected' then 'Verification could not be completed'
        else 'Verification pending'
      end,
      case new.verification_status
        when 'verified' then 'Your B2B account is verified — you can now place export orders.'
        when 'rejected' then 'We could not verify your business details. Please contact support.'
        else 'Your verification is being reviewed again.'
      end,
      'kyc'
    );
  end if;
  return null;
end;
$$;

drop trigger if exists client_kyc_notify on public.client_profiles;
create trigger client_kyc_notify
  after update on public.client_profiles
  for each row execute function public.trg_kyc_notify();

-- ---------------------------------------------------------------------------
-- 13. Role helpers — used by RLS policies
-- ---------------------------------------------------------------------------
create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'super_admin' and is_active
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role in ('admin', 'super_admin')
      and is_active
  );
$$;

-- ---------------------------------------------------------------------------
-- 14. Role management RPCs (called by the Railway API)
-- ---------------------------------------------------------------------------

-- Promote a client to admin + register them as a handler. Super admin only.
create or replace function public.promote_to_admin(target_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_super_admin() then
    raise exception 'ONLY_SUPER_ADMIN';
  end if;
  if exists (select 1 from public.profiles where id = target_user_id and role = 'super_admin') then
    raise exception 'CANNOT_MODIFY_SUPER_ADMIN';
  end if;
  if not exists (select 1 from public.profiles where id = target_user_id) then
    raise exception 'PROFILE_NOT_FOUND';
  end if;

  update public.profiles set role = 'admin', updated_at = now() where id = target_user_id;

  insert into public.admin_handlers (user_id, full_name, email, is_active)
  values (
    target_user_id,
    (select full_name from public.profiles where id = target_user_id),
    (select email from public.profiles where id = target_user_id),
    true
  )
  on conflict (user_id) do update set is_active = true;
end;
$$;

-- Demote an admin back to client. Super admin only.
create or replace function public.demote_to_client(target_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_super_admin() then
    raise exception 'ONLY_SUPER_ADMIN';
  end if;
  if exists (select 1 from public.profiles where id = target_user_id and role = 'super_admin') then
    raise exception 'CANNOT_MODIFY_SUPER_ADMIN';
  end if;
  if not exists (select 1 from public.profiles where id = target_user_id) then
    raise exception 'PROFILE_NOT_FOUND';
  end if;

  update public.profiles set role = 'client', updated_at = now() where id = target_user_id;
  delete from public.admin_handlers where user_id = target_user_id;
end;
$$;

-- Bootstrap the first super admin. Callable from the Supabase SQL Editor
-- (auth.uid() is null) or by an existing super admin via the API.
create or replace function public.promote_to_super_admin(target_email text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  target_id uuid;
begin
  if auth.uid() is not null and not public.is_super_admin() then
    raise exception 'NOT_ALLOWED';
  end if;

  select id into target_id from public.profiles where lower(email) = lower(target_email);
  if target_id is null then
    raise exception 'PROFILE_NOT_FOUND';
  end if;

  update public.profiles set role = 'super_admin', updated_at = now() where id = target_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 15. Row Level Security (defense-in-depth; primary guards live in the API)
-- ---------------------------------------------------------------------------
alter table public.profiles        enable row level security;
alter table public.client_profiles enable row level security;
alter table public.admin_handlers  enable row level security;
alter table public.products        enable row level security;
alter table public.orders          enable row level security;
alter table public.order_items     enable row level security;
alter table public.notifications   enable row level security;

-- profiles ------------------------------------------------------------------
drop policy if exists "read own or admin" on public.profiles;
create policy "read own or admin" on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_admin());

drop policy if exists "update own profile" on public.profiles;
create policy "update own profile" on public.profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Column-level guard: authenticated users may NOT touch the role column.
revoke update on public.profiles from authenticated;
grant update (full_name, phone, company_name, country, updated_at)
  on public.profiles to authenticated;
grant select on public.profiles to authenticated;

-- client_profiles -----------------------------------------------------------
drop policy if exists "client crud own record" on public.client_profiles;
create policy "client crud own record" on public.client_profiles
  for all to authenticated
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid());

drop policy if exists "admin verifies clients" on public.client_profiles;
create policy "admin verifies clients" on public.client_profiles
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- admin_handlers ------------------------------------------------------------
drop policy if exists "admin reads handlers" on public.admin_handlers;
create policy "admin reads handlers" on public.admin_handlers
  for select to authenticated
  using (public.is_admin());

drop policy if exists "super admin manages handlers" on public.admin_handlers;
create policy "super admin manages handlers" on public.admin_handlers
  for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());

-- products ------------------------------------------------------------------
drop policy if exists "authenticated read products" on public.products;
create policy "authenticated read products" on public.products
  for select to authenticated
  using (is_active = true or public.is_admin());

drop policy if exists "admin manages products" on public.products;
create policy "admin manages products" on public.products
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- orders --------------------------------------------------------------------
drop policy if exists "client reads own orders" on public.orders;
create policy "client reads own orders" on public.orders
  for select to authenticated
  using (client_user_id = auth.uid() or public.is_admin());

drop policy if exists "client creates orders" on public.orders;
create policy "client creates orders" on public.orders
  for insert to authenticated
  with check (client_user_id = auth.uid());

drop policy if exists "admin updates orders" on public.orders;
create policy "admin updates orders" on public.orders
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- order_items ---------------------------------------------------------------
drop policy if exists "order items visible to owner or admin" on public.order_items;
create policy "order items visible to owner or admin" on public.order_items
  for select to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.orders o
      where o.id = order_id and o.client_user_id = auth.uid()
    )
  );

-- notifications -------------------------------------------------------------
drop policy if exists "read own notifications" on public.notifications;
create policy "read own notifications" on public.notifications
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "mark own notifications read" on public.notifications;
create policy "mark own notifications read" on public.notifications
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 16. Seed catalogue — only into an EMPTY table (safe on re-apply)
-- ---------------------------------------------------------------------------
insert into public.products (name, category, manufacturer, description, price, currency, min_order_qty)
select name, category, manufacturer, description, price, currency, min_order_qty
from (values
  ('Vitamin D3 60K Tablets',     'Vitamins & Supplements', 'HealthPlus Laboratories', 'Cholecalciferol 60000 IU tablets, export pack of 10x10.', 3.20, 'USD', 100),
  ('Metformin HCl 500 mg',       'Anti Diabetes',          'Wellness Pharma',        'Metformin hydrochloride tablets IP 500 mg, WHO-GMP certified.', 1.85, 'USD', 500),
  ('Amoxicillin 500 mg Capsules','Antibiotics',            'MediCore Labs',          'Broad-spectrum penicillin capsules, 10x10 alu-alu strips.', 2.40, 'USD', 500),
  ('Ivermectin 12 mg Tablets',   'Anti Parasite',          'HealthPlus Laboratories', 'Antiparasitic tablets for institutional and export supply.', 2.10, 'USD', 300),
  ('Paracetamol 650 mg Tablets', 'Pain Killers',           'Wellness Pharma',        'Analgesic and antipyretic tablets, bulk export cartons.', 0.95, 'USD', 1000),
  ('Atorvastatin 20 mg Tablets', 'Cardio Care',            'MediCore Labs',          'Statin tablets for cholesterol management, 10x10 blister packs.', 2.75, 'USD', 500),
  ('Diclofenac Gel 30 g',        'Pain Killers',           'DermaCare India',        'Topical NSAID gel for musculoskeletal pain, 30 g tubes.', 1.60, 'USD', 200),
  ('Cetirizine 10 mg Tablets',   'Anti Allergic',          'Wellness Pharma',        'Antihistamine tablets, 10x10 packs, export ready.', 1.10, 'USD', 1000)
) as seed(name, category, manufacturer, description, price, currency, min_order_qty)
where not exists (select 1 from public.products);

-- ---------------------------------------------------------------------------
-- 17. Product issue reports (client-submitted, triaged by admins)
-- ---------------------------------------------------------------------------
create table if not exists public.product_reports (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  order_id    uuid references public.orders (id) on delete set null,
  product_name text not null default '',
  issue_type  text not null default 'Other',
  details     text not null default '',
  status      text not null default 'open' check (status in ('open', 'reviewing', 'resolved')),
  created_at  timestamptz not null default now()
);

alter table public.product_reports enable row level security;

drop policy if exists "own reports" on public.product_reports;
create policy "own reports" on public.product_reports
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "insert own reports" on public.product_reports;
create policy "insert own reports" on public.product_reports
  for insert to authenticated
  with check (user_id = auth.uid());

-- ============================================================================
-- BOOTSTRAPPING THE FIRST SUPER ADMIN
--   1. Apply this schema, then register your owner account via the API
--      (POST /api/v1/auth/signup).
--   2. In the Supabase SQL Editor run:
--        select public.promote_to_super_admin('owner@yourdomain.com');
--   3. Sign in again — the API now authorises admin operations for you.
-- The smoke-test script bootstraps a temporary super admin automatically
-- using the service-role key (see backend/scripts/smoke-test.ps1).
-- ============================================================================
