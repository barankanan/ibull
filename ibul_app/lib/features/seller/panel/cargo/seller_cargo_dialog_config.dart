import 'package:ibul_app/models/seller_product.dart';
import 'package:ibul_app/services/seller_cargo_print_job_service.dart';

class SellerCargoDialogConfig {
  const SellerCargoDialogConfig({
    required this.sellerId,
    required this.storeName,
    required this.initialProvince,
    required this.initialDistrict,
    required this.walletReady,
    required this.walletAvailable,
    required this.walletError,
    required this.currencyFormat,
    required this.products,
    required this.loadProducts,
    required this.reloadWallet,
    required this.showWalletTopup,
    required this.createOrder,
    required this.createPrintJobs,
  });

  final String sellerId;
  final String storeName;
  final String initialProvince;
  final String initialDistrict;
  final bool Function() walletReady;
  final double Function() walletAvailable;
  final String? Function() walletError;
  final String Function(double value) currencyFormat;
  final List<SellerProduct> Function() products;
  final Future<List<SellerProduct>> Function() loadProducts;
  final Future<void> Function() reloadWallet;
  final Future<bool> Function() showWalletTopup;
  final Future<Map<String, dynamic>> Function({
    required String sellerId,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String city,
    required String district,
    String? building,
    double? customerLat,
    double? customerLng,
    required int quantity,
    required double unitPrice,
    List<Map<String, dynamic>>? productLines,
    String? note,
    String? storeName,
  }) createOrder;
  final Future<CargoKitchenPrintJobsResult> Function({
    required String restaurantId,
    required String orderId,
    required String orderNumber,
    required List<Map<String, dynamic>> orderItems,
    List<Map<String, dynamic>>? productLines,
    String? storeName,
    String? createdAt,
  }) createPrintJobs;
}
