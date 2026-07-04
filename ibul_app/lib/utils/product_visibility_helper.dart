import 'dart:convert';

import '../models/seller_product.dart';

/// Public storefront/catalog visibility rules for products.
///
/// Bir ürün vitrinde yalnızca şu koşullarda görünür:
/// 1. [status] aktif (`Aktif` / `active`)
/// 2. [approval_status] veya [admin_approval_status] açıkça onaylı
///    (`approved`, `onaylandi`, `onaylandı` …)
///
/// Null/boş approval alanları yalnızca projection'da alan varken reddedilir.
/// SELECT'ten approval kolonları düşmüşse (şema fallback) RLS sonucuna güvenilir.
class ProductVisibilityHelper {
  const ProductVisibilityHelper._();

  static const Set<String> _activeStatusTokens = {'aktif', 'active'};

  static const Set<String> _approvedApprovalTokens = {
    'approved',
    'onaylandi',
    'onaylandı',
    'onayli',
    'onaylı',
  };

  static const Set<String> _blockedStatusTokens = {
    'pending',
    'pending_review',
    'pending_approval',
    'bekleniyor',
    'onay bekliyor',
    'rejected',
    'reddedildi',
    'draft',
    'taslak',
    'passive',
    'pasif',
    'inactive',
    'cancelled',
    'deleted',
  };

  static const Set<String> _blockedApprovalTokens = {
    'pending',
    'pending_review',
    'pending_approval',
    'bekleniyor',
    'onay bekliyor',
    'rejected',
    'reddedildi',
    'draft',
    'taslak',
    'passive',
    'pasif',
    'cancelled',
    'deleted',
  };

  static String _normalizeToken(String? value) {
    return (value?.trim().toLowerCase() ?? '')
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  static bool isPublicCatalogProductStatus(String? status) {
    final normalized = _normalizeToken(status);
    if (normalized.isEmpty) return false;
    if (_blockedStatusTokens.contains(normalized)) return false;
    return _activeStatusTokens.contains(normalized);
  }

  static bool isApprovedApprovalStatus(String? approvalStatus) {
    final raw = approvalStatus?.trim().toLowerCase() ?? '';
    if (raw.isEmpty) return false;

    if (_blockedApprovalTokens.contains(raw) ||
        _blockedApprovalTokens.contains(_normalizeToken(raw))) {
      return false;
    }

    return _approvedApprovalTokens.contains(raw) ||
        _approvedApprovalTokens.contains(_normalizeToken(raw));
  }

  /// Ad-linked rows: active status required; empty approval is allowed when
  /// seller explicitly selected the SKU for a paid home_feature placement.
  static bool isAdLinkedDisplayProductMap(Map<String, dynamic> map) {
    return adLinkedDisplayRejectReason(map) == null;
  }

  static const Set<String> _adLinkedRejectedApprovalTokens = {
    'rejected',
    'reddedildi',
  };

  /// Human-readable reject reason for ad-linked trace; null when displayable.
  static String? adLinkedDisplayRejectReason(Map<String, dynamic> map) {
    final status = map['status']?.toString();
    if (!isPublicCatalogProductStatus(status)) {
      final normalized = _normalizeToken(status);
      const hardBlockedStatus = {
        'rejected',
        'reddedildi',
        'draft',
        'taslak',
        'passive',
        'pasif',
        'inactive',
        'cancelled',
        'deleted',
      };
      if (hardBlockedStatus.contains(normalized) ||
          hardBlockedStatus.contains(status?.trim().toLowerCase())) {
        return 'status_blocked:$status';
      }
      return 'status_inactive:$status';
    }

    final approval = map['approval_status']?.toString();
    final adminApproval = map['admin_approval_status']?.toString();
    final rejected = {
      ..._adLinkedRejectedApprovalTokens,
      ..._adLinkedRejectedApprovalTokens.map(_normalizeToken),
    };
    if (rejected.contains(approval?.trim().toLowerCase()) ||
        rejected.contains(adminApproval?.trim().toLowerCase()) ||
        rejected.contains(_normalizeToken(approval)) ||
        rejected.contains(_normalizeToken(adminApproval))) {
      return 'approval_rejected:${approval ?? adminApproval ?? 'unknown'}';
    }

    return null;
  }

  /// Raw Supabase row — use at query boundaries and list hydration.
  static bool isPublicVisibleProductMap(Map<String, dynamic> map) {
    if (!isPublicCatalogProductStatus(map['status']?.toString())) {
      return false;
    }

    final hasApprovalKey = map.containsKey('approval_status');
    final hasAdminApprovalKey = map.containsKey('admin_approval_status');
    if (!hasApprovalKey && !hasAdminApprovalKey) {
      // RLS-filtered row; approval columns omitted from lightweight SELECT.
      return true;
    }

    final approval = map['approval_status']?.toString();
    final adminApproval = map['admin_approval_status']?.toString();
    return isApprovedApprovalStatus(approval) ||
        isApprovedApprovalStatus(adminApproval);
  }

  static bool isPublicVisibleSellerProduct(SellerProduct product) {
    return isPublicCatalogProductStatus(product.status);
  }

  static List<Map<String, dynamic>> filterPublicProductMaps(
    Iterable<Map<String, dynamic>> rows,
  ) {
    return rows
        .where(isPublicVisibleProductMap)
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  /// Sepete ekleme için: public görünür + stok alanı varsa > 0 olmalı.
  static bool isCustomerCartEligibleMap(Map<String, dynamic> map) {
    if (!isPublicVisibleProductMap(map)) {
      return false;
    }
    final stock = map['stock'];
    if (stock is num && stock <= 0) {
      return false;
    }
    return true;
  }

  static String? catalogFieldValue(
    Map<String, dynamic> map, {
    required String field,
    List<String> specificationKeys = const [],
  }) {
    final direct = map[field]?.toString().trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final keys = specificationKeys.isEmpty
        ? <String>[field, _toSnakeCase(field)]
        : specificationKeys;
    return _readSpecificationValue(map['specifications'], keys);
  }

  static String? catalogBarcode(Map<String, dynamic> map) {
    return catalogFieldValue(
      map,
      field: 'barcode',
      specificationKeys: const ['barcode', 'barkod'],
    );
  }

  static String? catalogModelCode(Map<String, dynamic> map) {
    return catalogFieldValue(
      map,
      field: 'model_code',
      specificationKeys: const ['model_code', 'modelCode', 'model kodu'],
    );
  }

  static List<Map<String, dynamic>> dedupeOtherSellerRows(
    Iterable<Map<String, dynamic>> rows, {
    String? excludeSellerId,
    String? excludeProductId,
    int limit = 10,
  }) {
    final excludedSeller = excludeSellerId?.trim() ?? '';
    final excludedProduct = excludeProductId?.trim() ?? '';
    final seenSellers = <String>{};
    final deduped = <Map<String, dynamic>>[];

    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final productId = row['id']?.toString().trim() ?? '';
      final sellerId = row['seller_id']?.toString().trim() ?? '';
      if (excludedProduct.isNotEmpty && productId == excludedProduct) {
        continue;
      }
      if (excludedSeller.isNotEmpty && sellerId == excludedSeller) {
        continue;
      }
      if (sellerId.isNotEmpty && !seenSellers.add(sellerId)) {
        continue;
      }
      deduped.add(row);
      if (deduped.length >= limit) {
        break;
      }
    }

    return deduped;
  }

  static String _toSnakeCase(String value) {
    return value
        .replaceAllMapped(
          RegExp('([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)}_${match.group(2)}',
        )
        .toLowerCase();
  }

  static String? _readSpecificationValue(
    dynamic specifications,
    List<String> keys,
  ) {
    Map<String, dynamic>? specs;
    if (specifications is Map) {
      specs = Map<String, dynamic>.from(specifications);
    } else if (specifications is String && specifications.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(specifications);
        if (decoded is Map) {
          specs = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
    }
    if (specs == null) return null;

    for (final key in keys) {
      final value = specs[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
