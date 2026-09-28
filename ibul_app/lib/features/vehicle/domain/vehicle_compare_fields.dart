import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';
import 'vehicle_catalog.dart';

typedef VehicleCompareRow = ({
  String label,
  String Function(VehicleListing listing) value,
});

abstract final class VehicleCompareFields {
  static String listingKind(VehicleListing listing) {
    final sale = listing.listingType.allowsSale;
    final rental = listing.listingType.allowsRental;
    if (sale && rental) return 'Satılık / Kiralık';
    if (rental) return 'Kiralık';
    return 'Satılık';
  }

  static String headlinePrice(VehicleListing listing) {
    if (listing.listingType.allowsSale &&
        listing.salePrice != null &&
        listing.salePrice! > 0) {
      return VehicleMoney.format(listing.salePrice!);
    }
    if (listing.rental != null && listing.rental!.dailyPrice > 0) {
      return '${VehicleMoney.format(listing.rental!.dailyPrice)} / gün';
    }
    return 'Fiyat sorulur';
  }

  static List<VehicleCompareRow> rowsFor(List<VehicleListing> listings) {
    return [
      (label: 'İlan tipi', value: listingKind),
      (label: 'Satış fiyatı', value: _salePrice),
      (label: 'Marka', value: (listing) => _dash(listing.specs.brand)),
      (label: 'Model', value: (listing) => _dash(listing.specs.model)),
      (label: 'Versiyon', value: (listing) => _dash(listing.specs.version)),
      (
        label: 'Yıl',
        value: (listing) =>
            listing.specs.year > 0 ? '${listing.specs.year}' : '—',
      ),
      (
        label: 'Kilometre',
        value: (listing) => listing.specs.mileageKm == null
            ? '—'
            : VehicleMoney.km(listing.specs.mileageKm!),
      ),
      (label: 'Yakıt', value: (listing) => _dash(listing.specs.fuel)),
      (label: 'Vites', value: (listing) => _dash(listing.specs.transmission)),
      (label: 'Kasa tipi', value: (listing) => _dash(listing.specs.bodyType)),
      (
        label: 'Motor hacmi',
        value: (listing) => listing.specs.engineCc == null
            ? '—'
            : '${VehicleMoney.format(listing.specs.engineCc!, withSuffix: false)} cc',
      ),
      (
        label: 'Motor gücü',
        value: (listing) =>
            listing.specs.powerHp == null ? '—' : '${listing.specs.powerHp} HP',
      ),
      (label: 'Çekiş', value: (listing) => _dash(listing.specs.drive)),
      (label: 'Renk', value: (listing) => _dash(listing.specs.color)),
      (label: 'Araç durumu', value: _condition),
      (
        label: 'Konum',
        value: (listing) => _dash(
          [
            listing.city,
            listing.district,
          ].whereType<String>().where((part) => part.isNotEmpty).join(' / '),
        ),
      ),
      (
        label: 'Tramer',
        value: (listing) => listing.specs.tramerAmount == null
            ? '—'
            : VehicleMoney.format(listing.specs.tramerAmount!),
      ),
      (label: 'Takas', value: (listing) => listing.tradeIn ? 'Uygun' : '—'),
      (label: 'Garanti', value: (listing) => _dash(listing.specs.warranty)),
      (label: 'Boya / Değişen', value: _damage),
      (label: 'Kiralama durumu', value: _rentalStatus),
      (
        label: 'Günlük fiyat',
        value: (listing) => listing.rental == null
            ? '—'
            : VehicleMoney.format(listing.rental!.dailyPrice),
      ),
      (
        label: 'Haftalık fiyat',
        value: (listing) => listing.rental?.weeklyPrice == null
            ? '—'
            : VehicleMoney.format(listing.rental!.weeklyPrice!),
      ),
      (
        label: 'Aylık fiyat',
        value: (listing) => listing.rental?.monthlyPrice == null
            ? '—'
            : VehicleMoney.format(listing.rental!.monthlyPrice!),
      ),
      (
        label: 'Depozito',
        value: (listing) => listing.rental == null
            ? '—'
            : VehicleMoney.format(listing.rental!.deposit),
      ),
      (
        label: 'Minimum kiralama süresi',
        value: (listing) =>
            listing.rental == null ? '—' : '${listing.rental!.minDays} gün',
      ),
      (
        label: 'Maksimum kiralama süresi',
        value: (listing) =>
            listing.rental == null ? '—' : '${listing.rental!.maxDays} gün',
      ),
      (
        label: 'KM limiti',
        value: (listing) => listing.rental?.kmLimitPerDay == null
            ? '—'
            : '${listing.rental!.kmLimitPerDay} km/gün',
      ),
      ..._featureRows(listings),
    ];
  }

  static String _dash(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? '—' : text;
  }

  static String _salePrice(VehicleListing listing) {
    if (!listing.listingType.allowsSale) return '—';
    if (listing.salePrice == null || listing.salePrice! <= 0) return '—';
    return VehicleMoney.format(listing.salePrice!);
  }

  static const _featuredIds = [
    'abs',
    'esp',
    'lane_keep',
    'blind_spot',
    'park_sensor',
    'rear_camera',
    'ac',
    'carplay',
    'android_auto',
  ];

  static List<VehicleCompareRow> _featureRows(List<VehicleListing> listings) {
    final ids = <String>{..._featuredIds};
    for (final listing in listings) {
      ids.addAll(listing.featureIds);
    }
    return [
      for (final id in ids)
        (
          label: VehicleCatalog.featureLabel(id) ?? id,
          value: (listing) => listing.featureIds.contains(id) ? 'Var' : '—',
        ),
    ];
  }

  static String _damage(VehicleListing listing) {
    final raw = listing.extras['damage_parts'];
    if (raw is Map && raw.isNotEmpty) {
      var painted = 0;
      var replaced = 0;
      for (final value in raw.values) {
        final state = value.toString();
        if (state == 'painted' || state == 'local_painted') painted += 1;
        if (state == 'replaced') replaced += 1;
      }
      if (painted == 0 && replaced == 0) return 'Orijinal';
      return 'Boyalı: $painted · Değişen: $replaced';
    }
    final painted = (listing.specs.paintedParts ?? '').trim();
    final replaced = (listing.specs.replacedParts ?? '').trim();
    if (painted.isEmpty && replaced.isEmpty) return '—';
    return [
      if (painted.isNotEmpty) 'Boyalı: $painted',
      if (replaced.isNotEmpty) 'Değişen: $replaced',
    ].join(' · ');
  }

  static String _condition(VehicleListing listing) {
    final raw = listing.extras['condition']?.toString().trim() ?? '';
    if (raw == 'new') return 'Sıfır';
    if (raw == 'used' || raw == 'second_hand') return 'İkinci el';
    return _dash(raw);
  }

  static String _rentalStatus(VehicleListing listing) {
    if (!listing.listingType.allowsRental) return 'Satılık';
    if (listing.listingType.allowsSale) return 'Satılık / Kiralık';
    return 'Kiralık';
  }
}
