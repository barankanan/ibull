import '../../../models/seller_product.dart';
import '../../../services/store_service.dart';
import 'product_quick_edit_models.dart';

class ProductQuickEditService {
  ProductQuickEditService({StoreService? storeService})
    : _storeService = storeService ?? StoreService();

  final StoreService _storeService;

  Future<SellerProduct> save(ProductQuickEditDraft draft) {
    final validationError = draft.validationError;
    if (validationError != null) {
      throw Exception(validationError);
    }

    return _storeService.updateProductQuickEdit(
      product: draft.originalProduct,
      name: draft.trimmedName,
      price: draft.parsedPrice!,
      stock: draft.parsedStock!,
      status: draft.storageStatus,
      replacementImage: draft.selectedImageFile,
    );
  }
}
