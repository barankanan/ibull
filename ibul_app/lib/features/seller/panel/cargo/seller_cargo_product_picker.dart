import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../models/seller_product.dart';
import 'seller_cargo_order_line.dart';

Future<SellerProduct?> showSellerCargoProductPicker({
  required BuildContext context,
  required List<SellerProduct> products,
}) {
  return showDialog<SellerProduct>(
    context: context,
    builder: (dialogContext) {
      return _SellerCargoProductPickerDialog(products: products);
    },
  );
}

class _SellerCargoProductPickerDialog extends StatefulWidget {
  const _SellerCargoProductPickerDialog({required this.products});

  final List<SellerProduct> products;

  @override
  State<_SellerCargoProductPickerDialog> createState() =>
      _SellerCargoProductPickerDialogState();
}

class _SellerCargoProductPickerDialogState
    extends State<_SellerCargoProductPickerDialog> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filterSellerCargoProducts(
      widget.products,
      _searchController.text,
    );

    return AlertDialog(
      title: const Text('Ürün Seç'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('seller_cargo_product_search'),
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Ürün adı veya kodu ara...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Satıcınıza ait eşleşen ürün bulunamadı.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        final code = sellerCargoProductCode(product);
                        final price = sellerCargoUnitPrice(product);
                        return ListTile(
                          key: Key('seller_cargo_product_${product.id}'),
                          dense: true,
                          leading: const Icon(
                            Icons.inventory_2_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            code.isEmpty ? 'Kod yok' : code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          trailing: Text(
                            '₺${price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2A44),
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Iptal'),
        ),
      ],
    );
  }
}
