-- Yazıcı ayarları: personel izni sunucu tarafında `managePrintSettings` ile hizalanır.
--
-- Canlıda doğrulanan durum (salt-okunur pg_policies, 2026-11-21):
--  * printers, stations, station_printers: yalnız işletme sahibi yazabiliyordu
--    (auth.uid() = restaurant_id). `managePrintSettings` verilmiş personel
--    sayfayı görüyor ama yazıcı ekleme / istasyon eşleştirme sunucuda 42501 ile
--    reddediliyordu.
--  * restaurant_print_station_configs: FOR ALL, user_can_access_restaurant()
--    kapısındaydı; bu fonksiyon `manageOrders` VEYA `viewOrders` demek. Yani
--    yalnız sipariş gören/alan personel yazıcı servisini açıp kapatabiliyor,
--    `managePrintSettings` verilmiş personel ise yazamıyordu (ters hizalama).
--
-- Bu migration:
--  * yazıcı yazma izni = işletme sahibi VEYA `managePrintSettings` (restaurant_has_permission
--    sahibi de kapsar; şifre değiştirme zorunluluğu, şube ve aktiflik denetimleri
--    o fonksiyondan gelir),
--  * okuma politikalarına (`*_waiter_select`) dokunmaz: garson ürün/istasyon
--    bilgisini okumaya devam eder,
--  * `manageStaff`, kullanıcı/şifre yönetimi veya başka izin vermez.
--
-- Geri alma: aşağıdaki *_print_settings_write politikalarını silip
-- restaurant_print_station_configs_owner_all'ı eski ifadeyle yeniden oluşturun
-- (using/with check = public.user_can_access_restaurant(restaurant_id)).

begin;

drop policy if exists printers_print_settings_write on public.printers;
create policy printers_print_settings_write
on public.printers
for all
to authenticated
using (public.restaurant_has_permission(restaurant_id, 'managePrintSettings'))
with check (public.restaurant_has_permission(restaurant_id, 'managePrintSettings'));

drop policy if exists stations_print_settings_write on public.stations;
create policy stations_print_settings_write
on public.stations
for all
to authenticated
using (public.restaurant_has_permission(restaurant_id, 'managePrintSettings'))
with check (public.restaurant_has_permission(restaurant_id, 'managePrintSettings'));

drop policy if exists station_printers_print_settings_write on public.station_printers;
create policy station_printers_print_settings_write
on public.station_printers
for all
to authenticated
using (
  exists (
    select 1 from public.stations s
    where s.id = station_printers.station_id
      and public.restaurant_has_permission(s.restaurant_id, 'managePrintSettings')
  )
)
with check (
  exists (
    select 1 from public.stations s
    where s.id = station_printers.station_id
      and public.restaurant_has_permission(s.restaurant_id, 'managePrintSettings')
  )
  and exists (
    select 1 from public.printers p
    where p.id = station_printers.printer_id
      and public.restaurant_has_permission(p.restaurant_id, 'managePrintSettings')
  )
);

-- Yazıcı servisi ayarı: sipariş görme/alma izni yazma hakkı vermez.
drop policy if exists restaurant_print_station_configs_owner_all
  on public.restaurant_print_station_configs;
drop policy if exists restaurant_print_station_configs_print_settings_write
  on public.restaurant_print_station_configs;
create policy restaurant_print_station_configs_print_settings_write
on public.restaurant_print_station_configs
for all
to authenticated
using (public.restaurant_has_permission(restaurant_id, 'managePrintSettings'))
with check (public.restaurant_has_permission(restaurant_id, 'managePrintSettings'));
-- Okuma: restaurant_print_station_configs_waiter_select değişmeden kalır.

commit;
