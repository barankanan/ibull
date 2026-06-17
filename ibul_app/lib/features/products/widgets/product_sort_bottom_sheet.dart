import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../models/product_filter_models.dart';

class ProductSortBottomSheet extends StatefulWidget {
  const ProductSortBottomSheet({
    super.key,
    required this.initialSort,
    required this.onApply,
  });

  final ProductSortOption initialSort;
  final ValueChanged<ProductSortOption> onApply;

  static Future<void> show({
    required BuildContext context,
    required ProductSortOption initialSort,
    required ValueChanged<ProductSortOption> onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ProductSortBottomSheet(
        initialSort: initialSort,
        onApply: onApply,
      ),
    );
  }

  @override
  State<ProductSortBottomSheet> createState() => _ProductSortBottomSheetState();
}

class _ProductSortBottomSheetState extends State<ProductSortBottomSheet> {
  late ProductSortOption _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSort;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sıralama',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...ProductSortOptionX.selectable.map((option) {
                final isSelected = _selected == option;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(option.label),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => setState(() => _selected = option),
                );
              }),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selected = ProductSortOption.recommended;
                        });
                      },
                      child: const Text('Temizle'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        widget.onApply(_selected);
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Uygula'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
