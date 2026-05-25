import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/mixed_service_order.dart';
import 'package:ibul_app/models/seller_product.dart';

void main() {
  group('MixedServiceOrder.resolveProductKind', () {
    test('category Servis does not imply service template', () {
      expect(
        MixedServiceOrder.resolveProductKind(
          category: 'Yemek',
          subCategory: 'Servis',
        ),
        'standard',
      );
    });

    test('product name Servis does not affect resolution', () {
      final product = SellerProduct(
        id: 'p1',
        name: 'Ciğer Servis',
        brand: 'Test',
        mainCategory: 'Yemek',
        subCategory: 'Servis',
        price: 380,
        stock: 10,
        sku: 'SKU1',
        status: 'pending_approval',
        createdAt: DateTime(2026),
        specifications: '{"preparationTime":15,"serviceType":"Masa"}',
      );

      expect(MixedServiceOrder.isTemplateProduct(product), isFalse);
      expect(MixedServiceOrder.productTypeFromProduct(product), 'standard');
    });

    test('explicit service template metadata still resolves as template', () {
      final product = SellerProduct(
        id: 'tpl1',
        name: 'Karışık Servis',
        brand: 'Test',
        mainCategory: 'Yemek',
        subCategory: 'Servis',
        price: 0,
        stock: 999,
        sku: 'TPL1',
        status: 'Aktif',
        createdAt: DateTime(2026),
        specifications: MixedServiceOrder.encodeTemplateSpecifications(
          pricingMode: MixedServiceOrder.autoSumPriceMode,
          fixedPrice: 0,
          manualPriceAllowed: false,
          templateItems: const <Map<String, dynamic>>[
            {'product_id': 'p1', 'product_name': 'Tavuk', 'quantity': 1},
          ],
        ),
      );

      expect(MixedServiceOrder.isTemplateProduct(product), isTrue);
      expect(
        MixedServiceOrder.productTypeFromProduct(product),
        MixedServiceOrder.serviceTemplateProductType,
      );
      expect(MixedServiceOrder.templateTypeLabelFromProduct(product), 'Servis');
    });
  });
}
