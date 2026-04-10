import 'package:ibul_app/models/product_pricing.dart';
import 'package:ibul_app/models/seller_product.dart';
import 'package:ibul_app/services/store_service.dart';

import 'bulk_product_import_models.dart' show BulkProductSelectedFile;
import 'bulk_product_price_stock_csv_parser.dart';
import 'bulk_product_price_stock_update_models.dart';
import 'bulk_product_price_stock_update_validator.dart';

class BulkProductPriceStockUpdateService {
  BulkProductPriceStockUpdateService({
    StoreService? storeService,
    BulkProductPriceStockCsvParser? parser,
    BulkProductPriceStockUpdateValidator? validator,
  }) : _storeService = storeService ?? StoreService(),
       _parser = parser ?? const BulkProductPriceStockCsvParser(),
       _validator = validator ?? const BulkProductPriceStockUpdateValidator();

  final StoreService _storeService;
  final BulkProductPriceStockCsvParser _parser;
  final BulkProductPriceStockUpdateValidator _validator;

  Future<BulkProductPriceStockUpdatePreview> buildPreview(
    BulkProductSelectedFile file,
  ) async {
    final BulkProductPriceStockCsvDocument document = _parser.parseBytes(
      file.bytes,
    );
    final List<SellerProduct> existingProducts = await _storeService
        .getSellerProductsSnapshot();
    return _validator.validate(
      fileName: file.name,
      document: document,
      existingProducts: existingProducts,
    );
  }

  Future<BulkProductPriceStockUpdateExecutionSummary> updateValidRows(
    BulkProductPriceStockUpdatePreview preview,
  ) async {
    final List<BulkProductPriceStockPreviewRow> updatableRows = preview.rows
        .where((BulkProductPriceStockPreviewRow row) => row.isUpdatable)
        .toList(growable: false);

    int updatedRows = 0;
    final List<BulkProductPriceStockUpdateFailure> failures =
        <BulkProductPriceStockUpdateFailure>[];

    for (final BulkProductPriceStockPreviewRow row in updatableRows) {
      final BulkProductPriceStockUpdatePlan? plan = row.updatePlan;
      if (plan == null) {
        continue;
      }

      try {
        await _storeService.updateProductPriceStockStatus(
          productId: plan.currentProduct.id,
          price: plan.newPrice,
          stock: plan.newStock,
          pricingType: plan.currentProduct.pricingType,
          portionPrice:
              plan.currentProduct.resolvedPricingType ==
                  ProductPricingType.portion
              ? plan.newPrice
              : plan.currentProduct.portionPrice,
          pricePerKg:
              plan.currentProduct.resolvedPricingType ==
                  ProductPricingType.weight
              ? plan.newPrice
              : plan.currentProduct.pricePerKg,
          status: plan.statusToPersist,
        );
        updatedRows++;
      } catch (error) {
        failures.add(
          BulkProductPriceStockUpdateFailure(
            rowNumber: row.rowNumber,
            sku: row.sku,
            message: _friendlyError(error),
          ),
        );
      }
    }

    return BulkProductPriceStockUpdateExecutionSummary(
      totalRows: preview.totalRows,
      updatedRows: updatedRows,
      invalidRows: preview.invalidRowCount,
      unchangedRows: preview.unchangedRowCount,
      failedRows: failures.length,
      failures: failures,
    );
  }

  String _friendlyError(Object error) {
    final String message = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Ürün güncellenirken hata: ', '')
        .replaceFirst('Fiyat ve stok güncellenirken hata: ', '')
        .trim();
    if (message.isEmpty) {
      return 'Güncelleme tamamlanamadı.';
    }
    return message;
  }
}
