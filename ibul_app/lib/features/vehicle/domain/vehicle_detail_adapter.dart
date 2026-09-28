import 'package:flutter/material.dart';

import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';
import '../widgets/vehicle_detail_spec_table.dart';
import 'vehicle_catalog.dart';

enum VehicleDetailCtaAction {
  selectRentalDates,
  rentNow,
  bookAppointment,
  askSeller,
}

class VehicleQuickSpec {
  const VehicleQuickSpec({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;
}

class VehicleRentalInfoRow {
  const VehicleRentalInfoRow({
    required this.label,
    required this.value,
    this.interactive = false,
  });

  final String label;
  final String value;
  final bool interactive;
}

class VehicleRentalInfoGroup {
  const VehicleRentalInfoGroup({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<VehicleRentalInfoRow> rows;
}

class VehicleDetailCtaPair {
  const VehicleDetailCtaPair({
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.primaryAction,
    required this.secondaryAction,
  });

  final String primaryLabel;
  final String secondaryLabel;
  final VehicleDetailCtaAction primaryAction;
  final VehicleDetailCtaAction secondaryAction;
}

/// Maps a vehicle listing onto the shared product-detail chrome.
abstract final class VehicleDetailAdapter {
  static bool isRental(VehicleListing listing) =>
      listing.listingType.allowsRental;

  static bool isSale(VehicleListing listing) => listing.listingType.allowsSale;

  static List<String> breadcrumbParts(VehicleListing listing) {
    final title = listing.title.trim();
    final clipped = title.length > 40 ? '${title.substring(0, 40)}...' : title;
    return [
      'iBul',
      listing.specs.brand,
      listing.gallery?.name.trim() ?? 'Galeri',
      'Araç',
      clipped,
    ].where((part) => part.trim().isNotEmpty).toList(growable: false);
  }

  static VehicleDetailCtaPair ctas(VehicleListing listing) {
    final rental = isRental(listing);
    final sale = isSale(listing);
    if (rental && !sale) {
      return const VehicleDetailCtaPair(
        primaryLabel: 'KİRALAMA TARİHİ SEÇ',
        secondaryLabel: 'ŞİMDİ KİRALA',
        primaryAction: VehicleDetailCtaAction.selectRentalDates,
        secondaryAction: VehicleDetailCtaAction.rentNow,
      );
    }
    if (rental && sale) {
      return const VehicleDetailCtaPair(
        primaryLabel: 'KİRALAMA TARİHİ SEÇ',
        secondaryLabel: 'GÖRÜŞME PLANLA',
        primaryAction: VehicleDetailCtaAction.selectRentalDates,
        secondaryAction: VehicleDetailCtaAction.bookAppointment,
      );
    }
    return const VehicleDetailCtaPair(
      primaryLabel: 'GÖRÜŞME PLANLA',
      secondaryLabel: 'SATICIYA SOR',
      primaryAction: VehicleDetailCtaAction.bookAppointment,
      secondaryAction: VehicleDetailCtaAction.askSeller,
    );
  }

  static List<VehicleQuickSpec> quickSpecs(VehicleListing listing) {
    final schema = VehicleTypeCatalog.of(listing.vehicleClass);
    final s = listing.specs;
    final items = <VehicleQuickSpec>[
      if (s.year > 0)
        VehicleQuickSpec(
          value: '${s.year}',
          label: 'Yıl',
          icon: Icons.event_outlined,
        ),
      if (schema.shows('mileageKm') && s.mileageKm != null && s.mileageKm! > 0)
        VehicleQuickSpec(
          value: VehicleMoney.km(s.mileageKm!),
          label: 'Kilometre',
          icon: Icons.speed_outlined,
        ),
      if (schema.shows('fuel') && (s.fuel ?? '').trim().isNotEmpty)
        VehicleQuickSpec(
          value: s.fuel!.trim(),
          label: 'Yakıt',
          icon: Icons.local_gas_station_outlined,
        ),
      if (schema.shows('transmission') &&
          (s.transmission ?? '').trim().isNotEmpty)
        VehicleQuickSpec(
          value: s.transmission!.trim(),
          label: 'Vites',
          icon: Icons.settings_outlined,
        ),
      if (schema.shows('bodyType') && (s.bodyType ?? '').trim().isNotEmpty)
        VehicleQuickSpec(
          value: s.bodyType!.trim(),
          label: 'Kasa',
          icon: Icons.directions_car_outlined,
        ),
      if ((s.version ?? '').trim().isNotEmpty)
        VehicleQuickSpec(
          value: s.version!.trim(),
          label: 'Paket',
          icon: Icons.workspace_premium_outlined,
        ),
    ];
    if (items.length < 6 &&
        schema.shows('powerHp') &&
        s.powerHp != null &&
        s.powerHp! > 0) {
      items.add(
        VehicleQuickSpec(
          value: '${s.powerHp} hp',
          label: 'Güç',
          icon: Icons.bolt_outlined,
        ),
      );
    }
    if (items.length < 6 &&
        schema.shows('color') &&
        (s.color ?? '').trim().isNotEmpty) {
      items.add(
        VehicleQuickSpec(
          value: s.color!.trim(),
          label: 'Renk',
          icon: Icons.palette_outlined,
        ),
      );
    }
    return items.take(6).toList(growable: false);
  }

  static List<VehicleRentalInfoGroup> rentalGroups(VehicleListing listing) {
    final rental = listing.rental;
    if (rental == null || !rental.rentalEnabled) return const [];
    final delivery = <VehicleRentalInfoRow>[
      if (rental.galleryPickup)
        const VehicleRentalInfoRow(
          label: 'Teslimat noktası',
          value: 'Galeriden teslim',
          interactive: true,
        ),
      if (rental.mapPointDelivery)
        const VehicleRentalInfoRow(
          label: 'Harita noktası',
          value: 'Seçilen konum',
          interactive: true,
        ),
      if (rental.homeDelivery)
        const VehicleRentalInfoRow(
          label: 'Evden teslim',
          value: 'Adrese getirilir',
          interactive: true,
        ),
    ];
    final terms = <VehicleRentalInfoRow>[
      if (rental.minDays > 0)
        VehicleRentalInfoRow(
          label: 'Minimum gün',
          value: '${rental.minDays} gün',
        ),
      if (rental.maxDays > 0)
        VehicleRentalInfoRow(
          label: 'Maksimum gün',
          value: '${rental.maxDays} gün',
        ),
      if (rental.kmLimitPerDay != null && rental.kmLimitPerDay! > 0)
        VehicleRentalInfoRow(
          label: 'Günlük KM',
          value: '${rental.kmLimitPerDay} km',
        ),
      if (rental.extraKmPrice != null && rental.extraKmPrice! > 0)
        VehicleRentalInfoRow(
          label: 'Ek KM',
          value: VehicleMoney.format(rental.extraKmPrice!),
        ),
      if (rental.minDriverAge != null && rental.minDriverAge! > 0)
        VehicleRentalInfoRow(
          label: 'Sürücü yaşı',
          value: '${rental.minDriverAge}+',
        ),
      if (rental.minLicenseYears != null && rental.minLicenseYears! > 0)
        VehicleRentalInfoRow(
          label: 'Ehliyet',
          value: '${rental.minLicenseYears} yıl',
        ),
    ];
    final fees = <VehicleRentalInfoRow>[
      if (rental.deposit > 0)
        VehicleRentalInfoRow(
          label: 'Depozito',
          value: VehicleMoney.format(rental.deposit),
        ),
      if (rental.weeklyPrice != null && rental.weeklyPrice! > 0)
        VehicleRentalInfoRow(
          label: 'Haftalık',
          value: VehicleMoney.format(rental.weeklyPrice!),
        ),
      if (rental.monthlyPrice != null && rental.monthlyPrice! > 0)
        VehicleRentalInfoRow(
          label: 'Aylık',
          value: VehicleMoney.format(rental.monthlyPrice!),
        ),
      if (rental.instantBooking)
        const VehicleRentalInfoRow(label: 'Anında rezervasyon', value: 'Var'),
      if (rental.requiresApproval)
        const VehicleRentalInfoRow(label: 'Onay', value: 'Gerekir'),
    ];
    return [
      if (delivery.isNotEmpty)
        VehicleRentalInfoGroup(
          title: 'Teslim Alma',
          icon: Icons.directions_car_outlined,
          rows: delivery,
        ),
      if (terms.isNotEmpty)
        VehicleRentalInfoGroup(
          title: 'Kiralama Koşulları',
          icon: Icons.event_available_outlined,
          rows: terms,
        ),
      if (fees.isNotEmpty)
        VehicleRentalInfoGroup(
          title: 'Ücretler & Güvence',
          icon: Icons.verified_user_outlined,
          rows: fees,
        ),
    ];
  }

  static List<(String, String)> rentalOptionRows(VehicleListing listing) {
    return [
      for (final group in rentalGroups(listing))
        for (final row in group.rows) (row.label, row.value),
    ];
  }

  static List<String> tabs(VehicleListing listing) {
    return [
      'Araç Açıklaması',
      'Yakın Lokasyon',
      'Araç Özellikleri',
      if (isRental(listing)) 'Teslimat / Kiralama',
    ];
  }

  static String ctaSubtitle(VehicleListing listing) {
    final rental = listing.rental;
    if (isRental(listing) && rental != null && rental.minDays > 0) {
      return 'Minimum ${rental.minDays} gün';
    }
    return VehicleDetailSpecBuilder.locationOf(listing);
  }

  static String tabActionLabel(int index) {
    return index == 1 ? 'Yakında Arat' : 'İncele';
  }
}
