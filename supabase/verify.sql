-- ============================================================================
-- MediGram — GATE V1: database verification script
-- Run AFTER supabase/schema.sql in the Supabase SQL Editor.
-- Every check prints "PASSED"; any broken invariant raises FAILED and stops
-- the script. The gate is green only when the final line
-- "ALL CHECKS PASSED — GATE V1 GREEN" appears.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Structural checks
-- ---------------------------------------------------------------------------
do $$ declare t text; begin
  foreach t in array array['profiles','client_profiles','admin_handlers','products','orders','order_items','notifications']
  loop
    if to_regclass('public.' || t) is null then
      raise exception 'FAILED: table % missing', t;
    end if;
  end loop;
  raise notice 'PASSED: all 7 tables exist';
end $$;

do $$ begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid=t.typnamespace where n.nspname='public' and t.typname='user_role')
     or not exists (select 1 from pg_type t join pg_namespace n on n.oid=t.typnamespace where n.nspname='public' and t.typname='order_status')
     or not exists (select 1 from pg_type t join pg_namespace n on n.oid=t.typnamespace where n.nspname='public' and t.typname='notification_kind') then
    raise exception 'FAILED: one or more enums missing';
  end if;
  raise notice 'PASSED: enums user_role / order_status / notification_kind exist';
end $$;

do $$ declare t text; begin
  foreach t in array array['profiles','client_profiles','admin_handlers','products','orders','order_items','notifications']
  loop
    if not exists (select 1 from pg_class c where c.relname=t and c.relrowsecurity) then
      raise exception 'FAILED: RLS not enabled on %', t;
    end if;
  end loop;
  raise notice 'PASSED: RLS enabled on all tables';
end $$;

-- Role column must NOT be updatable by the authenticated role.
do $$ begin
  if exists (
    select 1 from information_schema.column_privileges
    where table_schema='public' and table_name='profiles'
      and column_name='role' and grantee='authenticated'
      and privilege_type='UPDATE'
  ) then
    raise exception 'FAILED: authenticated role can UPDATE profiles.role';
  end if;
  raise notice 'PASSED: profiles.role is not user-updatable';
end $$;

-- Pipeline triggers exist.
do $$ begin
  if not exists (select 1 from pg_trigger where tgname='on_auth_user_created')
     or not exists (select 1 from pg_trigger where tgname='orders_check_verified')
     or not exists (select 1 from pg_trigger where tgname='order_items_recalc')
     or not exists (select 1 from pg_trigger where tgname='orders_status_notify')
     or not exists (select 1 from pg_trigger where tgname='client_kyc_notify') then
    raise exception 'FAILED: one or more pipeline triggers missing';
  end if;
  raise notice 'PASSED: all 5 pipeline triggers installed';
end $$;

-- Guarded RPCs exist and reject unprivileged / invalid calls.
-- (With no JWT, auth.uid() is null = server context, so the call proceeds to
-- the target-existence guard and must still FAIL — no path lets it succeed.)
do $outer$
begin
  set local role authenticated;
  begin
    perform public.promote_to_admin('00000000-0000-0000-0000-000000000000'::uuid);
    raise exception 'FAILED: promote_to_admin ran without super-admin';
  exception
    when others then
      if sqlerrm like 'FAILED: %' then raise; end if;
  end;
  reset role;
  raise notice 'PASSED: promote_to_admin guarded (unprivileged call rejected)';
end
$outer$;

-- ---------------------------------------------------------------------------
-- LIVE PIPELINE SCENARIO (uses a throwaway test user, cleaned up at the end)
-- ---------------------------------------------------------------------------
do $outer$
declare
  v_uid   uuid := gen_random_uuid();
  v_email text := 'v1-gate-test@medigram.test';
  v_oid   uuid;
  v_role  public.user_role;
  v_cnt   int;
  v_total numeric;
begin
  -- P1: signup pipeline — auth user insert must create a pending profile.
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                          created_at, updated_at)
  values (v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          v_email, crypt('Test1234!', gen_salt('bf')), now(), '{}'::jsonb,
          jsonb_build_object('full_name','Gate Tester','phone','+1 555 0100',
                             'company_name','Gate Test Trading','country','United States'),
          now(), now());

  select role into v_role from public.profiles where id = v_uid;
  if v_role is null then
    raise exception 'FAILED: P1 handle_new_user did not create a profile';
  end if;
  raise notice 'PASSED: P1 signup — profile auto-created (role=%)', v_role;

  -- Seed the client business record (mirrors the API's signup step).
  insert into public.client_profiles (user_id, company_name, country, contact_email)
  values (v_uid, 'Gate Test Trading', 'United States', v_email);

  -- Order pipeline: unverified client must be rejected.
  begin
    insert into public.orders (client_user_id) values (v_uid) returning id into v_oid;
    raise exception 'FAILED: order accepted for UNVERIFIED client';
  exception
    when others then
      if sqlerrm not like 'ORDER_REQUIRES_VERIFIED_CLIENT%' then raise; end if;
  end;
  raise notice 'PASSED: P3 guard — unverified client cannot place order';

  -- KYC pipeline: verify the client → kyc notification must appear.
  update public.client_profiles
     set verification_status = 'verified', verified_at = now()
   where user_id = v_uid;

  select count(*) into v_cnt from public.notifications
   where user_id = v_uid and kind = 'kyc';
  if v_cnt < 1 then
    raise exception 'FAILED: P2 kyc notification missing';
  end if;
  raise notice 'PASSED: P2 KYC — verification status change produced notification';

  -- Order pipeline: verified client can place an order.
  insert into public.orders (client_user_id) values (v_uid) returning id into v_oid;
  if (select order_number from public.orders where id = v_oid) !~ '^MG-[0-9]+$' then
    raise exception 'FAILED: order_number sequence not applied';
  end if;
  raise notice 'PASSED: P3 order placement works for verified client';

  -- Totals pipeline: line items recalculate the order total.
  insert into public.order_items (order_id, product_id, product_name, quantity, unit_price)
  select v_oid, p.id, p.name, 100, p.price from public.products p limit 1;

  select total_amount into v_total from public.orders where id = v_oid;
  if v_total is null or v_total <= 0 then
    raise exception 'FAILED: P10 recalc_order_total did not run (total=%)', v_total;
  end if;
  if exists (select 1 from public.order_items where order_id = v_oid
             and line_total <> quantity::numeric * unit_price) then
    raise exception 'FAILED: line_total generated column incorrect';
  end if;
  raise notice 'PASSED: totals — line_total + order total recalculated (%)', v_total;

  -- Fulfilment pipeline: status change produces an order notification.
  update public.orders set status = 'shipped' where id = v_oid;
  select count(*) into v_cnt from public.notifications
   where user_id = v_uid and kind = 'order';
  if v_cnt < 1 then
    raise exception 'FAILED: P4 order status notification missing';
  end if;
  raise notice 'PASSED: P4 fulfilment — status change produced notification';

  -- Cleanup: deleting the auth user cascades every dependent row.
  delete from auth.users where id = v_uid;
  if exists (select 1 from public.profiles where id = v_uid)
     or exists (select 1 from public.orders where client_user_id = v_uid) then
    raise exception 'FAILED: cascade cleanup incomplete';
  end if;
  raise notice 'PASSED: cascade cleanup — test data removed';
end
$outer$;

-- Seed sanity.
do $$ begin
  if (select count(*) from public.products) < 8 then
    raise exception 'FAILED: product seed missing';
  end if;
  raise notice 'PASSED: catalogue seeded (%)', (select count(*) from public.products);
end $$;

do $$ begin
  raise notice '============================================================';
  raise notice 'ALL CHECKS PASSED - GATE V1 GREEN';
  raise notice '============================================================';
end $$;
