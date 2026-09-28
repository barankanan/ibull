import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../domain/vehicle_catalog.dart';
import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';

class VehicleSpecGroup {
  const VehicleSpecGroup(this.title, this.rows);
  final String title;
  final List<(String, String)> rows;
}

abstract final class VehicleDetailSpecBuilder {
  static String priceOf(VehicleListing listing) {
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

  static String locationOf(VehicleListing listing) {
    return [
      if ((listing.district ?? '').trim().isNotEmpty) listing.district!.trim(),
      if ((listing.city ?? '').trim().isNotEmpty) listing.city!.trim(),
    ].join(' / ');
  }

  static List<(IconData, String)> highlights(VehicleListing listing) {
    final schema = VehicleTypeCatalog.of(listing.vehicleClass);
    final s = listing.specs;
    return [
      if (schema.shows('mileageKm') && s.mileageKm != null && s.mileageKm! > 0)
        (Icons.speed_outlined, VehicleMoney.km(s.mileageKm!)),
      if (s.year > 0) (Icons.event_outlined, '${s.year}'),
      if (schema.shows('fuel') && (s.fuel ?? '').isNotEmpty)
        (Icons.local_gas_station_outlined, s.fuel!),
      if (schema.shows('transmission') && (s.transmission ?? '').isNotEmpty)
        (Icons.settings_outlined, s.transmission!),
      if (schema.shows('powerHp') && s.powerHp != null && s.powerHp! > 0)
        (Icons.bolt_outlined, '${s.powerHp} hp'),
      if (schema.shows('bodyType') && (s.bodyType ?? '').isNotEmpty)
        (Icons.directions_car_outlined, s.bodyType!),
    ];
  }

  static List<String> headlineMeta(VehicleListing listing) {
    final schema = VehicleTypeCatalog.of(listing.vehicleClass);
    final s = listing.specs;
    return [
      if (s.year > 0) '${s.year}',
      if (schema.shows('mileageKm') && s.mileageKm != null && s.mileageKm! > 0)
        VehicleMoney.km(s.mileageKm!),
      if (schema.shows('fuel') && (s.fuel ?? '').isNotEmpty) s.fuel!,
      if (schema.shows('transmission') && (s.transmission ?? '').isNotEmpty)
        s.transmission!,
      if (schema.shows('powerHp') && s.powerHp != null && s.powerHp! > 0)
        '${s.powerHp} hp',
      if (schema.shows('bodyType') && (s.bodyType ?? '').isNotEmpty)
        s.bodyType!,
    ];
  }

  static List<(String, String)> compactRows(VehicleListing listing) {
    return [for (final group in groups(listing)) ...group.rows];
  }

  static List<(String, String)> sidebarRows(VehicleListing listing) {
    const preferred = <String>{
      'Yıl',
      'Kilometre',
      'Yakıt',
      'Vites',
      'Kasa tipi',
      'Motor hacmi',
      'Motor gücü',
      'Çekiş',
      'Renk',
      'Garanti',
      'Kimden',
      'Takas',
      'Marka',
      'Model',
      'Versiyon',
    };
    final ranked = compactRows(
      listing,
    ).where((row) => preferred.contains(row.$1)).toList(growable: false);
    if (ranked.length >= 8) return ranked.take(12).toList(growable: false);
    return compactRows(listing).take(12).toList(growable: false);
  }

  static List<VehicleSpecGroup> groups(VehicleListing listing) {
    final schema = VehicleTypeCatalog.of(listing.vehicleClass);
    final s = listing.specs;
    final x = listing.extras;
    String? extra(String key) {
      final value = x[key];
      if (value == null) return null;
      final text = value.toString().trim();
      if (text.isEmpty ||
          text == 'null' ||
          text == 'undefined' ||
          text == '0') {
        return null;
      }
      return text;
    }

    bool shows(String field) => schema.shows(field);
    final general = <(String, String)>[
      if (s.brand.trim().isNotEmpty) ('Marka', s.brand),
      if (s.model.trim().isNotEmpty) ('Model', s.model),
      if ((s.version ?? '').trim().isNotEmpty) ('Versiyon', s.version!.trim()),
      if (s.year > 0) ('Yıl', '${s.year}'),
      if (shows('mileageKm') && s.mileageKm != null && s.mileageKm! > 0)
        ('Kilometre', VehicleMoney.km(s.mileageKm!)),
      if (shows('hoursOperated') && extra('hours_operated') != null)
        ('Çalışma saati', extra('hours_operated')!),
      if (shows('fuel') && (s.fuel ?? '').isNotEmpty) ('Yakıt', s.fuel!),
      if (shows('transmission') && (s.transmission ?? '').isNotEmpty)
        ('Vites', s.transmission!),
      if (shows('bodyType') && (s.bodyType ?? '').isNotEmpty)
        ('Kasa tipi', s.bodyType!),
      if (shows('hullType') && extra('hull_type') != null)
        ('Gövde', extra('hull_type')!),
      if (shows('color') && (s.color ?? '').isNotEmpty) ('Renk', s.color!),
      if (shows('doors') && s.doors != null) ('Kapı', '${s.doors}'),
      if (shows('seats') && s.seats != null) ('Koltuk', '${s.seats}'),
    ];
    final motor = <(String, String)>[
      if (shows('engineCc') && s.engineCc != null && s.engineCc! > 0)
        (
          'Motor hacmi',
          '${VehicleMoney.format(s.engineCc!, withSuffix: false)} cc',
        ),
      if (shows('powerHp') && s.powerHp != null && s.powerHp! > 0)
        ('Motor gücü', '${s.powerHp} hp'),
      if (shows('torqueNm') && extra('torque_nm') != null)
        ('Tork', '${extra('torque_nm')} Nm'),
      if (shows('cylinders') && extra('cylinders') != null)
        ('Silindir', extra('cylinders')!),
      if (shows('drive') && (s.drive ?? '').isNotEmpty) ('Çekiş', s.drive!),
      if (shows('cooling') && extra('cooling') != null)
        ('Soğutma', extra('cooling')!),
      if (shows('axles') && extra('axles') != null) ('Dingil', extra('axles')!),
      if (shows('payloadKg') && extra('payload_kg') != null)
        ('Taşıma', '${extra('payload_kg')} kg'),
    ];
    final listingInfo = <(String, String)>[
      (
        'İlan tipi',
        switch (listing.listingType) {
          VehicleListingType.sale => 'Satılık',
          VehicleListingType.rental => 'Kiralık',
          VehicleListingType.both => 'Satılık / Kiralık',
        },
      ),
      if (listing.gallery != null && listing.gallery!.name.trim().isNotEmpty)
        ('Kimden', listing.gallery!.name.trim()),
      if (listing.tradeIn) ('Takas', 'Uygun'),
      if (listing.financing) ('Kredi', 'Uygun'),
      ('Pazarlık', listing.negotiable ? 'Yapılır' : 'Yapılmaz'),
      if (extra('plate_status') != null) ('Plaka', extra('plate_status')!),
    ];
    final condition = extra('condition');
    final statusInfo = <(String, String)>[
      if (condition != null)
        ('Araç durumu', condition == 'new' ? 'Sıfır' : 'İkinci el'),
      if ((s.warranty ?? '').trim().isNotEmpty) ('Garanti', s.warranty!.trim()),
      if (s.hasExpertise) ('Ekspertiz', 'Beyan edildi'),
      if (s.hasDamage) ('Hasar kaydı', 'Var'),
      if (s.tramerAmount != null && s.tramerAmount! > 0)
        ('Tramer', VehicleMoney.format(s.tramerAmount!)),
    ];
    final rental = listing.rental;
    final rentalInfo = <(String, String)>[
      if (rental != null && rental.rentalEnabled) ...[
        ('Günlük fiyat', VehicleMoney.format(rental.dailyPrice)),
        if (rental.weeklyPrice != null && rental.weeklyPrice! > 0)
          ('Haftalık fiyat', VehicleMoney.format(rental.weeklyPrice!)),
        if (rental.monthlyPrice != null && rental.monthlyPrice! > 0)
          ('Aylık fiyat', VehicleMoney.format(rental.monthlyPrice!)),
        if (rental.minDays > 0) ('Minimum gün', '${rental.minDays} gün'),
        if (rental.deposit > 0)
          ('Depozito', VehicleMoney.format(rental.deposit)),
        if (rental.kmLimitPerDay != null && rental.kmLimitPerDay! > 0)
          ('Km limiti', '${rental.kmLimitPerDay} km/gün'),
        if (rental.galleryPickup) ('Galeriden teslim', 'Var'),
        if (rental.homeDelivery) ('Evden teslim', 'Var'),
      ],
    ];
    return [
      if (general.isNotEmpty) VehicleSpecGroup('Genel', general),
      if (motor.isNotEmpty) VehicleSpecGroup('Motor & Performans', motor),
      if (listingInfo.isNotEmpty) VehicleSpecGroup('Araç', listingInfo),
      if (statusInfo.isNotEmpty) VehicleSpecGroup('Durum', statusInfo),
      if (rentalInfo.isNotEmpty) VehicleSpecGroup('Kiralama', rentalInfo),
    ];
  }
}

class VehicleDetailSpecTable extends StatelessWidget {
  const VehicleDetailSpecTable({super.key, required this.listing});

  final VehicleListing listing;

  @override
  Widget build(BuildContext context) {
    final groups = VehicleDetailSpecBuilder.groups(listing);
    if (groups.isEmpty) {
      return const Text(
        'Araç bilgisi henüz eklenmedi.',
        style: TextStyle(color: AppColors.textGrey),
      );
    }
    final wide = MediaQuery.sizeOf(context).width > 900;
    if (!wide) {
      return Column(
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _SpecGroupCard(group: groups[i]),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final group in groups)
              SizedBox(
                width: width < 240 ? constraints.maxWidth : width,
                child: _SpecGroupCard(group: group),
              ),
          ],
        );
      },
    );
  }
}

class _SpecGroupCard extends StatelessWidget {
  const _SpecGroupCard({required this.group});

  final VehicleSpecGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              group.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          for (var i = 0; i < group.rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      group.rows[i].$1,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      group.rows[i].$2,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != group.rows.length - 1)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: Colors.grey.shade100,
              ),
          ],
        ],
      ),
    );
  }
}
