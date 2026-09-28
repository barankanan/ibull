import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../domain/vehicle_catalog.dart';
import '../models/vehicle_listing.dart';

class VehicleDetailDamageSection extends StatelessWidget {
  const VehicleDetailDamageSection({super.key, required this.listing});

  final VehicleListing listing;

  static bool visible(VehicleListing listing) {
    return listing.specs.hasDamage ||
        listing.specs.hasExpertise ||
        (listing.specs.tramerAmount ?? 0) > 0 ||
        (listing.specs.paintedParts ?? '').trim().isNotEmpty ||
        (listing.specs.replacedParts ?? '').trim().isNotEmpty ||
        listing.extras['damage_parts'] is Map;
  }

  bool get _hasPartMap => listing.extras['damage_parts'] is Map;

  Map<String, String> get _parts {
    final raw = listing.extras['damage_parts'];
    if (raw is! Map) {
      return {
        for (final part in VehicleCatalog.damageParts) part.id: 'original',
      };
    }
    return {
      for (final part in VehicleCatalog.damageParts)
        part.id: (raw[part.id] ?? 'unspecified').toString(),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPartMap &&
        (listing.specs.paintedParts ?? '').trim().isEmpty &&
        (listing.specs.replacedParts ?? '').trim().isEmpty) {
      final tramer = listing.specs.tramerAmount;
      return Text(
        [
          'Boya / değişen bilgisi girilmemiş.',
          if (tramer != null && tramer > 0)
            'Tramer: ${VehicleMoney.format(tramer)}',
          if (listing.specs.hasExpertise) 'Ekspertiz beyan edildi.',
        ].join(' '),
        style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
      );
    }
    final parts = _parts;
    final painted = parts.values.where((v) => v == 'painted').length;
    final local = parts.values.where((v) => v == 'local_painted').length;
    final replaced = parts.values.where((v) => v == 'replaced').length;
    final original = parts.values.where((v) => v == 'original').length;
    final unspecified = parts.values.where((v) => v == 'unspecified').length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        final schema = _schema(parts);
        final summary = _summary(
          original: original,
          local: local,
          painted: painted,
          replaced: replaced,
          unspecified: unspecified,
        );
        final written = _writtenSummary(parts);
        if (!wide) {
          return Column(
            children: [
              schema,
              const SizedBox(height: 12),
              summary,
              const SizedBox(height: 12),
              written,
            ],
          );
        }
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: schema),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: summary),
              ],
            ),
            const SizedBox(height: 14),
            written,
          ],
        );
      },
    );
  }

  Widget _legend(Color color, String label, [int? count]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1F1F1F)),
            ),
          ),
          if (count != null)
            Text(
              '$count',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }

  Widget _schema(Map<String, String> parts) {
    Widget cell(String id) {
      final part = VehicleCatalog.damageParts
          .where((p) => p.id == id)
          .firstOrNull;
      return Expanded(
        child: Container(
          height: 30,
          alignment: Alignment.center,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: _color(parts[id] ?? 'unspecified'),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Text(
            part?.label ?? id,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        children: [
          Row(children: [cell('hood')]),
          Row(children: [cell('lf_fender'), cell('rf_fender')]),
          Row(children: [cell('lf_door'), cell('rf_door')]),
          Row(children: [cell('lr_door'), cell('rr_door')]),
          Row(children: [cell('lr_fender'), cell('rr_fender')]),
          Row(children: [cell('trunk')]),
          Row(children: [cell('roof')]),
          Row(children: [cell('front_bumper'), cell('rear_bumper')]),
        ],
      ),
    );
  }

  Widget _summary({
    required int original,
    required int local,
    required int painted,
    required int replaced,
    required int unspecified,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legend(const Color(0xFF86EFAC), 'Orijinal', original),
          _legend(const Color(0xFFFDE68A), 'Lokal boyalı', local),
          _legend(const Color(0xFFFDBA74), 'Boyalı', painted),
          _legend(const Color(0xFFFCA5A5), 'Değişen', replaced),
          _legend(const Color(0xFFE5E7EB), 'Belirtilmemiş', unspecified),
          const SizedBox(height: 10),
          Text(
            'Tramer: ${listing.specs.tramerAmount == null || listing.specs.tramerAmount! <= 0 ? 'Belirtilmedi' : VehicleMoney.format(listing.specs.tramerAmount!)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _writtenSummary(Map<String, String> parts) {
    String names(String state) {
      final labels = [
        for (final part in VehicleCatalog.damageParts)
          if (parts[part.id] == state) part.label,
      ];
      return labels.isEmpty ? 'Yok' : labels.join(', ');
    }

    final tramer = listing.specs.tramerAmount;
    final tramerText = tramer == null || tramer <= 0
        ? 'Belirtilmedi'
        : VehicleMoney.format(tramer);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _namedLine('Orijinal', names('original')),
          _namedLine('Lokal boyalı', names('local_painted')),
          _namedLine('Boyalı', names('painted')),
          _namedLine('Değişen', names('replaced')),
          _namedLine('Belirtilmemiş', names('unspecified')),
          const SizedBox(height: 8),
          Text(
            'Tramer: $tramerText',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _namedLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
      ),
    );
  }

  Color _color(String state) {
    return switch (state) {
      'original' => const Color(0xFF86EFAC),
      'local_painted' => const Color(0xFFFDE68A),
      'painted' => const Color(0xFFFDBA74),
      'replaced' => const Color(0xFFFCA5A5),
      _ => const Color(0xFFE5E7EB),
    };
  }
}
