-- MediGram catalogue seed - SHORT LIST (8 products, owner-approved).
-- Replaces the ENTIRE catalogue: deletes every existing product first.
-- Safe to re-run.
begin;

delete from public.products;

insert into public.products (name, category, manufacturer, description) values
  ('Modafeel 200 mg', 'ANTI-ANXIETY', 'MODAFINIL', '200 mg | JEERIMA'),
  ('Modasmart 400 mg', 'ANTI-ANXIETY', 'MODAFINIL', '400 mg | WINLIFE'),
  ('Abortion kit (divabort kit)', 'WOMEN''S PERSONAL USE', 'ABORTION PILLS', ''),
  ('Cenforce 100 mg', 'ED MEDICINES', 'SILDENAFIL', '100 mg | CENTURION'),
  ('Cenforce 200 mg', 'ED MEDICINES', 'SILDENAFIL', '200 mg | CENTURION'),
  ('Vidalista 20 mg', 'ED MEDICINES', 'TADALAFIL', '20 mg | CENTURION'),
  ('Vidalista 80 mg black', 'ED MEDICINES', 'TADALAFIL', '80 mg | CENTURION'),
  ('Nervigesic 300 mg', 'PAIN KILLERS', 'PREGABILIN', '300 mg | SIGNATURE');

-- Verification: total must be 8.
select count(*) as total_products from public.products;
select category, count(*) as products from public.products group by category order by category;

commit;