-- ===========================================================================
-- MediGram upgrade: product photos (admin-uploaded images)
-- Safe to re-run. Apply via the Supabase SQL Editor, or from backend/:
--   node scripts/run-sql.mjs ../supabase/add_product_images.sql
--
-- Adds:
--   1. products.image_url       — public URL of the admin-uploaded product
--                                 photo (usually Supabase Storage). Empty
--                                 string = no photo (catalogue falls back to
--                                 the bundled category product shot).
--   2. storage bucket
--      'product-images'         — public-read bucket the API uploads to
--                                 (backend POST /api/v1/uploads/product-image).
-- ===========================================================================

-- 1. Products: admin-uploaded product photo.
alter table public.products
  add column if not exists image_url text not null default '';

-- 2. Storage bucket for product photos — public so buyers can render the
--    images directly from the returned public URL.
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

-- 3. Public read policy (defense in depth; public buckets are readable, but
--    keep an explicit policy so access survives bucket-flag changes).
drop policy if exists "Public read product images" on storage.objects;
create policy "Public read product images"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'product-images');
