import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/services/review_repository.dart';
import 'package:ibul_app/services/review_service.dart';
import 'package:ibul_app/widgets/compare_page_helpers.dart';

void main() {
  test('yeni yorum product_id taşır', () {
    final item = <String, dynamic>{
      'product_id': 'prod-A',
      'product_code': 'SKU-9',
      'product_name': 'Kupa',
      'store_name': 'Mağaza',
      'seller_id': 'seller-1',
    };
    final payload = productReviewInsertPayload(
      productName: item['product_name'] as String,
      storeName: item['store_name'] as String,
      sellerId: item['seller_id'] as String,
      productImageUrl: '',
      productCode: item['product_code'] as String,
      rating: 5,
      comment: 'iyi',
      imageUrls: const [],
      userId: 'user-1',
      userName: 'Ali',
      productId: reviewProductIdFromOrderItem(item),
    );

    expect(payload['product_id'], 'prod-A');
    expect(payload['product_name'], 'Kupa');
    expect(payload['store_name'], 'Mağaza');
    expect(payload['seller_id'], 'seller-1');
    expect(payload['product_code'], 'SKU-9');
    expect(
      reviewProductIdFromOrderItem({'product_code': 'SKU-9'}),
      isNull,
    );
  });

  test('legacy null yorum ad ve mağaza ile bulunur', () {
    const review = {
      'product_id': null,
      'productName': 'Kupa',
      'storeName': 'Mağaza',
      'sellerId': 'seller-1',
      'comment': 'eski',
    };
    final visible = reviewsVisibleForProduct(
      productId: 'prod-A',
      productName: 'Kupa',
      storeName: 'Mağaza',
      sellerId: 'seller-1',
      reviews: const [review],
    );
    expect(visible, [review]);
  });

  test('product_id yanlış mağaza metnini yener', () {
    const review = {
      'productId': 'A',
      'productName': 'X',
      'storeName': 'OLD STORE NAME',
      'sellerId': 'S',
      'comment': 'id kazanır',
    };
    final onA = reviewsVisibleForProduct(
      productId: 'A',
      productName: 'X',
      storeName: 'Yeni Mağaza',
      sellerId: 'S',
      reviews: const [review],
    );
    final onOther = reviewsVisibleForProduct(
      productId: 'B',
      productName: 'X',
      storeName: 'OLD STORE NAME',
      sellerId: 'S',
      reviews: const [review],
    );
    expect(onA.single['comment'], 'id kazanır');
    expect(onOther, isEmpty);
  });

  test('aynı ad ve satıcıda product_id karışmaz', () {
    const review = {
      'productId': 'A',
      'productName': 'X',
      'storeName': 'Mağaza',
      'sellerId': 'S',
      'comment': 'yalnız A',
    };
    final onA = reviewsVisibleForProduct(
      productId: 'A',
      productName: 'X',
      storeName: 'Mağaza',
      sellerId: 'S',
      reviews: const [review],
    );
    final onB = reviewsVisibleForProduct(
      productId: 'B',
      productName: 'X',
      storeName: 'Mağaza',
      sellerId: 'S',
      reviews: const [review],
    );
    expect(onA, isNotEmpty);
    expect(onB, isEmpty);
  });

  test('belirsiz legacy yorum hiçbir ürüne yazılmaz', () {
    const review = {
      'productName': 'X',
      'storeName': 'Mağaza',
      'sellerId': 'S',
      'comment': 'eski',
    };
    final visible = reviewsVisibleForProduct(
      productId: 'A',
      productName: 'X',
      storeName: 'Mağaza',
      sellerId: 'S',
      legacyNameIsAmbiguous: true,
      reviews: const [review],
    );
    expect(visible, isEmpty);
  });

  test('karşılaştırma ve ürün detayı aynı kimliği kullanır', () {
    const review = {
      'productId': 'A',
      'productName': 'X',
      'storeName': 'OLD STORE NAME',
      'comment': 'ortak',
    };
    final product = Product(
      productId: 'A',
      name: 'X',
      brand: 'Marka',
      store: 'Yeni Mağaza',
      sellerId: 'S',
      price: '100 TL',
      rating: 0,
      reviewCount: 0,
      tags: const [],
      images: const [],
      category: 'Elektronik',
    );
    final compared = reviewsForCompareProduct(product, const [review]);
    final detail = reviewsVisibleForProduct(
      productId: product.productId,
      productName: product.name,
      storeName: product.store,
      sellerId: product.sellerId,
      reviews: const [review],
    );
    expect(compared.single['comment'], 'ortak');
    expect(detail.single['comment'], 'ortak');
  });
}
