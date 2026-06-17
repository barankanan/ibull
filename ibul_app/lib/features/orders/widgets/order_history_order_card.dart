import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';

import '../../../core/constants.dart';
import '../helpers/order_history_status_helper.dart';

const double kOrderHistoryActionChipHeight = 28;
const double kOrderHistoryActionChipHPadding = 10;

class OrderHistoryOrderCard extends StatelessWidget {
  const OrderHistoryOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    required this.onOpenProduct,
  });

  final Map<String, dynamic> order;
  final VoidCallback onTap;
  final VoidCallback onOpenProduct;

  @override
  Widget build(BuildContext context) {
    final items =
        (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final firstItem = items.isNotEmpty ? items.first : <String, dynamic>{};
    final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
    final resolved = OrderHistoryStatusHelper.resolveOrderStatus(
      (order['status']?.toString() ?? '').toLowerCase(),
      items,
    );
    final status = OrderHistoryStatusHelper.statusPresentation(resolved);
    final previewUrl = firstItem['product_image_url']?.toString();
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final orderNo = OrderHistoryStatusHelper.shortOrderNo(order);
    final dateText = createdAt != null
        ? OrderHistoryStatusHelper.formatPurchaseDate(createdAt)
        : '-';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onOpenProduct,
                  child: _PreviewThumb(url: previewUrl),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onTap,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstItem['store_name']?.toString() ?? 'Mağaza',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${items.length} ürün',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.end,
                      children: [
                        _StatusBadge(status: status),
                        _ReorderPill(onPressed: onOpenProduct),
                      ],
                    ),
                    IconButton(
                      onPressed: onTap,
                      icon: const Icon(Icons.chevron_right, size: 18),
                      color: Colors.grey.shade500,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tarih: $dateText',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tutar: ${total.toStringAsFixed(2)} TL',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No: #$orderNo',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final Map<String, dynamic> status;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kOrderHistoryActionChipHeight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kOrderHistoryActionChipHPadding),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: status['bg'] as Color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status['label'] as String,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: status['color'] as Color,
          ),
        ),
      ),
    );
  }
}

class _ReorderPill extends StatelessWidget {
  const _ReorderPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kOrderHistoryActionChipHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: kOrderHistoryActionChipHPadding),
          minimumSize: const Size(0, kOrderHistoryActionChipHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        child: const Text(
          'Tekrar Al',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _PreviewThumb extends StatelessWidget {
  const _PreviewThumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: ColoredBox(
          color: const Color(0xFFF3F4F6),
          child: (url ?? '').isNotEmpty
              ? OptimizedImage(
                  imageUrlOrPath: url!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                )
              : const Icon(Icons.image_outlined, size: 18, color: Colors.grey),
        ),
      ),
    );
  }
}
