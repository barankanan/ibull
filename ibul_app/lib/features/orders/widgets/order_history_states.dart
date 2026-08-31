import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../screens/cart_page.dart';
import '../../../widgets/ibul_page_state.dart';
import '../models/order_history_models.dart';

class OrderHistoryEmptyState extends StatelessWidget {
  const OrderHistoryEmptyState({super.key, required this.onShop});

  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    return IbulPageState.empty(
      icon: Icons.receipt_long_outlined,
      iconSize: 56,
      title: 'Henüz eski siparişin yok',
      titleSize: 18,
      titleWeight: FontWeight.w700,
      titleColor: AppColors.onSurface,
      message: 'İBUL’da alışveriş yaptıkça sipariş geçmişin burada görünecek.',
      actionLabel: 'Alışverişe Başla',
      onAction: onShop,
      padding: const EdgeInsets.all(32),
    );
  }
}

class OrderHistoryErrorState extends StatelessWidget {
  const OrderHistoryErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return IbulPageState.error(
      title: 'Siparişler yüklenemedi',
      message: 'Bağlantını kontrol edip tekrar deneyebilirsin.',
      onAction: onRetry,
    );
  }
}

class OrderHistoryLoadingList extends StatelessWidget {
  const OrderHistoryLoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 96,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }),
    );
  }
}

class SmartReorderFooter extends StatelessWidget {
  const SmartReorderFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Text(
          'Akıllı Tekrar Al • Yakında',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// @deprecated Use [SmartReorderFooter] on order history page.
class SmartReorderCard extends StatelessWidget {
  const SmartReorderCard({super.key});

  @override
  Widget build(BuildContext context) => const SmartReorderFooter();
}

void showReorderResultSheet(BuildContext context, ReorderResult result) {
  if (result.allBlocked) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bu siparişteki ürünler şu anda tekrar alınamıyor.'),
      ),
    );
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bazı ürünler sepete eklenemedi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              if (result.added.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Sepete eklenenler', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...result.added.map((line) => _lineTile(line.productName)),
              ],
              if (result.priceChanged.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Fiyatı değişenler', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Fiyatlar güncel mağaza fiyatlarına göre hesaplanır.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                ...result.priceChanged.map(
                  (line) => _lineTile(
                    '${line.productName} (${line.previousUnitPrice?.toStringAsFixed(2)} → ${line.currentUnitPrice?.toStringAsFixed(2)} TL)',
                  ),
                ),
              ],
              if (result.blocked.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._blockedSections(result.blocked),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Alışverişe Devam Et'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CartPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Sepete Git'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _lineTile(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}

List<Widget> _blockedSections(List<ReorderLineCheck> blocked) {
  final outOfStock = blocked
      .where((b) => b.outcome == ReorderItemOutcome.outOfStock)
      .toList();
  final notListed = blocked
      .where((b) => b.outcome == ReorderItemOutcome.notListed)
      .toList();
  final storeInactive = blocked
      .where((b) => b.outcome == ReorderItemOutcome.storeInactive)
      .toList();

  final widgets = <Widget>[];
  if (outOfStock.isNotEmpty) {
    widgets.add(const Text('Stokta olmayanlar', style: TextStyle(fontWeight: FontWeight.w700)));
    widgets.add(const SizedBox(height: 8));
    widgets.addAll(outOfStock.map((b) => _lineTile(b.productName)));
    widgets.add(const SizedBox(height: 8));
  }
  if (notListed.isNotEmpty) {
    widgets.add(const Text('Artık satışta olmayanlar', style: TextStyle(fontWeight: FontWeight.w700)));
    widgets.add(const SizedBox(height: 8));
    widgets.addAll(notListed.map((b) => _lineTile(b.productName)));
    widgets.add(const SizedBox(height: 8));
  }
  if (storeInactive.isNotEmpty) {
    widgets.add(const Text('Mağaza aktif değil', style: TextStyle(fontWeight: FontWeight.w700)));
    widgets.add(const SizedBox(height: 8));
    widgets.addAll(storeInactive.map((b) => _lineTile(b.productName)));
  }
  return widgets;
}
