-- Kitchen print routing seed data
-- Usage:
-- 1) Replace v_restaurant_id in the DO block with your store seller_id (uuid), OR
-- 2) Keep as-is to seed first available store.

do $$
declare
  v_restaurant_id uuid;
  v_kasap uuid;
  v_firin uuid;
  v_ocak uuid;
  v_bar uuid;

  v_kasap_printer uuid;
  v_firin_printer uuid;
  v_ocak_printer uuid;
  v_bar_printer uuid;
begin
  select seller_id
  into v_restaurant_id
  from public.stores
  order by created_at asc
  limit 1;

  if v_restaurant_id is null then
    raise exception 'Seed için stores tablosunda kayıt bulunamadı.';
  end if;

  insert into public.stations (restaurant_id, name, code, color, is_active)
  values
    (v_restaurant_id, 'Kasap', 'KASAP', '#DC2626', true),
    (v_restaurant_id, 'Fırın', 'FIRIN', '#EA580C', true),
    (v_restaurant_id, 'Ocak', 'OCAK', '#D97706', true),
    (v_restaurant_id, 'Bar', 'BAR', '#2563EB', true),
    (v_restaurant_id, 'Soğuk Mutfak', 'SOGUK', '#0EA5E9', true)
  on conflict (restaurant_id, code) do update
  set name = excluded.name,
      color = excluded.color,
      is_active = excluded.is_active;

  select id into v_kasap from public.stations where restaurant_id = v_restaurant_id and code = 'KASAP' limit 1;
  select id into v_firin from public.stations where restaurant_id = v_restaurant_id and code = 'FIRIN' limit 1;
  select id into v_ocak from public.stations where restaurant_id = v_restaurant_id and code = 'OCAK' limit 1;
  select id into v_bar from public.stations where restaurant_id = v_restaurant_id and code = 'BAR' limit 1;

  insert into public.printers (restaurant_id, name, code, connection_type, ip_address, port, paper_width_mm, is_active)
  values
    (v_restaurant_id, 'Kasap Yazıcısı', 'PRN-KASAP', 'network', '192.168.1.210', 9100, 80, true),
    (v_restaurant_id, 'Fırın Yazıcısı', 'PRN-FIRIN', 'network', '192.168.1.211', 9100, 80, true),
    (v_restaurant_id, 'Ocak Yazıcısı', 'PRN-OCAK', 'network', '192.168.1.212', 9100, 80, true),
    (v_restaurant_id, 'Bar Yazıcısı', 'PRN-BAR', 'network', '192.168.1.213', 9100, 80, true)
  on conflict (restaurant_id, code) do update
  set name = excluded.name,
      connection_type = excluded.connection_type,
      ip_address = excluded.ip_address,
      port = excluded.port,
      paper_width_mm = excluded.paper_width_mm,
      is_active = excluded.is_active;

  select id into v_kasap_printer from public.printers where restaurant_id = v_restaurant_id and code = 'PRN-KASAP' limit 1;
  select id into v_firin_printer from public.printers where restaurant_id = v_restaurant_id and code = 'PRN-FIRIN' limit 1;
  select id into v_ocak_printer from public.printers where restaurant_id = v_restaurant_id and code = 'PRN-OCAK' limit 1;
  select id into v_bar_printer from public.printers where restaurant_id = v_restaurant_id and code = 'PRN-BAR' limit 1;

  insert into public.station_printers (station_id, printer_id, is_primary)
  values
    (v_kasap, v_kasap_printer, true),
    (v_firin, v_firin_printer, true),
    (v_ocak, v_ocak_printer, true),
    (v_bar, v_bar_printer, true)
  on conflict (station_id, printer_id) do update
  set is_primary = excluded.is_primary;

  -- Example product routing
  update public.products
  set station_id = v_kasap,
      printer_routing_enabled = true
  where seller_id = v_restaurant_id
    and lower(name) in ('et tava');

  update public.products
  set station_id = v_firin,
      printer_routing_enabled = true
  where seller_id = v_restaurant_id
    and lower(name) in ('pide');

  update public.products
  set station_id = v_ocak,
      printer_routing_enabled = true
  where seller_id = v_restaurant_id
    and lower(name) in ('şiş tavuk', 'sis tavuk');

  update public.products
  set station_id = v_bar,
      printer_routing_enabled = true
  where seller_id = v_restaurant_id
    and lower(name) in ('kola');
end $$;
