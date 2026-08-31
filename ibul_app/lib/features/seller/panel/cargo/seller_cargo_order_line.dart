import '../../../../models/seller_product.dart';

class SellerCargoOrderLine {
  const SellerCargoOrderLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.productCode = '',
    this.productImageUrl,
    this.stationId,
    this.printerRoutingEnabled = true,
  });

  final String productId;
  final String productName;
  final String productCode;
  final String? productImageUrl;
  final String? stationId;
  final bool printerRoutingEnabled;
  final int quantity;
  final double unitPrice;

  double get lineTotal =>
      (quantity <= 0 ? 0 : quantity) * (unitPrice < 0 ? 0 : unitPrice);

  SellerCargoOrderLine copyWith({int? quantity, double? unitPrice}) {
    return SellerCargoOrderLine(
      productId: productId,
      productName: productName,
      productCode: productCode,
      productImageUrl: productImageUrl,
      stationId: stationId,
      printerRoutingEnabled: printerRoutingEnabled,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  Map<String, dynamic> toServiceMap() {
    final normalizedStationId = (stationId ?? '').trim();
    return <String, dynamic>{
      'product_id': productId,
      'product_name': productName,
      'product_code': productCode.trim().isEmpty
          ? productId
          : productCode.trim(),
      'product_image_url': productImageUrl,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': lineTotal,
      if (normalizedStationId.isNotEmpty) 'station_id': normalizedStationId,
      'printer_routing_enabled': printerRoutingEnabled,
    };
  }
}

double sellerCargoUnitPrice(SellerProduct product) {
  final discounted = product.discountPrice;
  if (discounted != null && discounted > 0) return discounted;
  final effective = product.effectiveBaseUnitPrice;
  if (effective > 0) return effective;
  return product.price;
}

String sellerCargoProductCode(SellerProduct product) {
  final sku = product.sku.trim();
  if (sku.isNotEmpty) return sku;
  return product.id;
}

SellerCargoOrderLine sellerCargoLineFromProduct(
  SellerProduct product, {
  int quantity = 1,
}) {
  final safeQuantity = quantity <= 0 ? 1 : quantity;
  return SellerCargoOrderLine(
    productId: product.id,
    productName: product.name,
    productCode: sellerCargoProductCode(product),
    productImageUrl: product.imageUrl,
    stationId: product.stationId?.trim().isEmpty == true
        ? null
        : product.stationId?.trim(),
    printerRoutingEnabled: product.printerRoutingEnabled,
    quantity: safeQuantity,
    unitPrice: sellerCargoUnitPrice(product),
  );
}

List<SellerCargoOrderLine> addOrIncrementSellerCargoLine(
  List<SellerCargoOrderLine> current,
  SellerProduct product,
) {
  final productId = product.id.trim();
  if (productId.isEmpty) return List<SellerCargoOrderLine>.from(current);
  final index = current.indexWhere((line) => line.productId == productId);
  if (index < 0) {
    return <SellerCargoOrderLine>[
      ...current,
      sellerCargoLineFromProduct(product),
    ];
  }
  final existing = current[index];
  final next = List<SellerCargoOrderLine>.from(current);
  next[index] = existing.copyWith(quantity: existing.quantity + 1);
  return next;
}

List<SellerCargoOrderLine> updateSellerCargoLineQuantity(
  List<SellerCargoOrderLine> current,
  String productId,
  int quantity,
) {
  if (quantity <= 0) {
    return current
        .where((line) => line.productId != productId)
        .toList(growable: false);
  }
  return current
      .map(
        (line) => line.productId == productId
            ? line.copyWith(quantity: quantity)
            : line,
      )
      .toList(growable: false);
}

double sellerCargoLinesSubtotal(List<SellerCargoOrderLine> lines) {
  return lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
}

String normalizeSellerCargoProductSearch(String raw) {
  return raw
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('Ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('Ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('Ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('Ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll('Ç', 'c')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<SellerProduct> filterSellerCargoProducts(
  List<SellerProduct> products,
  String query,
) {
  final needle = normalizeSellerCargoProductSearch(query);
  final owned = products
      .where((product) => product.id.trim().isNotEmpty)
      .toList(growable: false);
  if (needle.isEmpty) return owned;
  return owned
      .where((product) {
        final blob = normalizeSellerCargoProductSearch(
          [product.name, product.sku, product.id].join(' '),
        );
        return blob.contains(needle);
      })
      .toList(growable: false);
}
