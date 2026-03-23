import 'dart:convert';

import '../../models/db_category.dart';

Map<String, dynamic> asAdminMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  if (value is String && value.trim().startsWith('{')) {
    try {
      final decoded = json.decode(value);
      if (decoded is Map) {
        return decoded.map((key, item) => MapEntry(key.toString(), item));
      }
    } catch (_) {}
  }
  return const {};
}

DateTime? parseAdminDateTime(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}

List<DateTime> adminMonthStarts(int months) {
  final now = DateTime.now().toUtc();
  return List<DateTime>.generate(
    months,
    (index) => DateTime.utc(now.year, now.month - (months - 1) + index, 1),
  );
}

String adminMonthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

String adminMonthLabel(DateTime date) {
  const labels = <String>[
    'Oca',
    'Sub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Agu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];
  return labels[date.month - 1];
}

String humanizeAdminDeliveryType(
  dynamic raw,
  String Function(String value) titleCase,
) {
  final value = (raw ?? '').toString().trim().toLowerCase();
  switch (value) {
    case 'ihiz':
      return 'iHiz';
    case 'delivery':
    case 'standard':
      return 'Standart teslimat';
    case 'pickup':
      return 'Magazadan teslim';
    case 'express':
      return 'Hizli teslimat';
    default:
      return value.isEmpty ? 'Belirtilmedi' : titleCase(value);
  }
}

String shipmentStateLabel(dynamic shipmentStep, dynamic status) {
  final step = (shipmentStep ?? '').toString().trim().toLowerCase();
  final normalizedStatus = (status ?? '').toString().trim().toLowerCase();
  final value = step.isNotEmpty ? step : normalizedStatus;

  switch (value) {
    case 'delivered':
      return 'Teslim edildi';
    case 'out_for_delivery':
      return 'Dagitimda';
    case 'shipped':
    case 'transfer':
    case 'branch':
      return 'Yolda';
    case 'ready_to_ship':
      return 'Hazirlandi';
    case 'preparing':
    case 'confirmed':
    case 'new':
      return 'Hazirlaniyor';
    case 'cancelled':
    case 'cancelled_by_user':
    case 'return_requested':
    case 'returned':
      return 'Sorunlu / Iade';
    default:
      if (value.contains('cancel') || value.contains('return')) {
        return 'Sorunlu / Iade';
      }
      return 'Islemde';
  }
}

String normalizeAdminSearchText(dynamic raw) {
  return (raw ?? '')
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}

bool isIhizOrderItem(Map<String, dynamic> row) {
  final cargo = normalizeAdminSearchText(row['cargo_company']);
  if (cargo.contains('ihiz')) return true;
  if (cargo.isNotEmpty) return false;

  final step = normalizeAdminSearchText(row['shipment_step']);
  final status = normalizeAdminSearchText(row['status']);
  final hasCourierStep =
      step == 'out_for_delivery' || step == 'ready_to_ship' || step == 'branch';
  final hasCourierStatus =
      status == 'out_for_delivery' || status == 'ready_to_ship';
  return hasCourierStep || hasCourierStatus;
}

String adminNonEmptyText(dynamic raw, {required String fallback}) {
  final value = (raw ?? '').toString().trim();
  return value.isEmpty ? fallback : value;
}

String adminTitleCase(String value) {
  final parts = value
      .split(RegExp(r'[\s_-]+'))
      .where((part) => part.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) return value;
  return parts
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String adminNameFromEmail(String email) {
  final trimmed = email.trim();
  if (trimmed.isEmpty || !trimmed.contains('@')) {
    return 'Yeni kullanici';
  }
  return adminTitleCase(trimmed.split('@').first.replaceAll('.', ' '));
}

double adminAsDouble(dynamic raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse((raw ?? '').toString()) ?? 0;
}

int adminAsInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse((raw ?? '').toString()) ?? 0;
}

String extractAdminCityFromAddress(dynamic rawAddress) {
  final address = asAdminMap(rawAddress);
  if (address.isEmpty) {
    return 'Sehir yok';
  }
  return adminNonEmptyText(
    address['city'] ?? address['il'] ?? address['province'],
    fallback: 'Sehir yok',
  );
}

String pickFirstAdminText(
  Map<String, dynamic>? first,
  Map<String, dynamic>? second,
  List<String> keys,
) {
  for (final key in keys) {
    final fromFirst = (first?[key] ?? '').toString().trim();
    if (fromFirst.isNotEmpty) return fromFirst;
    final fromSecond = (second?[key] ?? '').toString().trim();
    if (fromSecond.isNotEmpty) return fromSecond;
  }
  return '';
}

DBCategory adminDbCategoryFromMap(Map<String, dynamic> data) {
  return DBCategory(
    id: (data['id'] as num?)?.toInt(),
    name: (data['name'] ?? '').toString(),
    iconName: data['icon_name']?.toString(),
    imageUrl: data['image_url']?.toString(),
    orderIndex: ((data['order_index'] as num?) ?? 0).toInt(),
    parentId: (data['parent_id'] as num?)?.toInt(),
    isActive: data['is_active'] == true,
  );
}

Map<String, dynamic> adminDbCategoryToMap(DBCategory category) {
  return {
    'name': category.name,
    'icon_name': category.iconName,
    'image_url': category.imageUrl,
    'order_index': category.orderIndex,
    'parent_id': category.parentId,
    'is_active': category.isActive,
  };
}
