-- ============================================================================
-- MediGram — clean reset for re-running schema.sql from scratch.
-- Drops all MediGram objects (tables, triggers, functions, types, sequence)
-- in FK-safe order. Supabase system objects (auth.users etc.) are untouched.
-- NOTE: destructive — only run when you want a fresh database.
-- ============================================================================

drop trigger if exists on_auth_user_created on auth.users;

drop table if exists public.notifications   cascade;
drop table if exists public.order_items     cascade;
drop table if exists public.orders          cascade;
drop table if exists public.products        cascade;
drop table if exists public.admin_handlers  cascade;
drop table if exists public.client_profiles cascade;
drop table if exists public.profiles        cascade;

drop sequence if exists public.order_number_seq;

drop function if exists public.handle_new_user();
drop function if exists public.check_order_client_verified();
drop function if exists public.recalc_order_total();
drop function if exists public.trg_order_notify();
drop function if exists public.trg_kyc_notify();
drop function if exists public.is_super_admin();
drop function if exists public.is_admin();
drop function if exists public.promote_to_admin(uuid);
drop function if exists public.demote_to_client(uuid);
drop function if exists public.promote_to_super_admin(text);

drop type if exists public.notification_kind;
drop type if exists public.order_status;
drop type if exists public.user_role;

-- Restore default table grants removed by the DROP cascade.
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on tables to postgres, anon, authenticated, service_role;
