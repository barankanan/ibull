alter table public.users
  add column if not exists product_lists jsonb not null default '[]'::jsonb;

comment on column public.users.product_lists is
  'Kullanicinin olusturdugu urun listeleri. Flutter tarafinda ProductList modeli olarak saklanir.';
