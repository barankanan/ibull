import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import 'seller_cargo_order_line.dart';

class SellerCargoProductLinesSection extends StatelessWidget {
  const SellerCargoProductLinesSection({
    super.key,
    required this.lines,
    required this.currencyFormat,
    required this.onAdd,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final List<SellerCargoOrderLine> lines;
  final String Function(double value) currencyFormat;
  final VoidCallback onAdd;
  final void Function(String productId, int quantity) onQuantityChanged;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Ürünler',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2A44),
                ),
              ),
            ),
            OutlinedButton.icon(
              key: const Key('seller_cargo_add_product'),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ürün Ekle'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                side: const BorderSide(color: Color(0xFFD0DBFF)),
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (lines.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Text(
              'Siparişe ürün eklemek için "Ürün Ekle"ye basın.',
              style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
            ),
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                for (var index = 0; index < lines.length; index++) ...[
                  if (index > 0)
                    Divider(height: 1, color: Colors.grey.shade200),
                  _SellerCargoProductLineRow(
                    line: lines[index],
                    currencyFormat: currencyFormat,
                    onQuantityChanged: onQuantityChanged,
                    onRemove: onRemove,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _SellerCargoProductLineRow extends StatelessWidget {
  const _SellerCargoProductLineRow({
    required this.line,
    required this.currencyFormat,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final SellerCargoOrderLine line;
  final String Function(double value) currencyFormat;
  final void Function(String productId, int quantity) onQuantityChanged;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2A44),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (line.productCode.trim().isNotEmpty) line.productCode,
                    '${line.quantity} x ${currencyFormat(line.unitPrice)}',
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          _QtyButton(
            icon: Icons.remove_rounded,
            onPressed: () =>
                onQuantityChanged(line.productId, line.quantity - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${line.quantity}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          _QtyButton(
            icon: Icons.add_rounded,
            onPressed: () =>
                onQuantityChanged(line.productId, line.quantity + 1),
          ),
          const SizedBox(width: 8),
          Text(
            currencyFormat(line.lineTotal),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2A44),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onRemove(line.productId),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF1F2A44)),
      ),
    );
  }
}

class SellerCargoOrderSummary extends StatelessWidget {
  const SellerCargoOrderSummary({
    super.key,
    required this.customerName,
    required this.customerPhone,
    required this.addressText,
    required this.lines,
    required this.shippingAmount,
    required this.currencyFormat,
  });

  final String customerName;
  final String customerPhone;
  final String addressText;
  final List<SellerCargoOrderLine> lines;
  final double shippingAmount;
  final String Function(double value) currencyFormat;

  @override
  Widget build(BuildContext context) {
    final subtotal = sellerCargoLinesSubtotal(lines);
    final shipping = shippingAmount < 0 ? 0.0 : shippingAmount;
    final total = subtotal + shipping;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD6E2FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sipariş Özeti',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2A44),
            ),
          ),
          const SizedBox(height: 8),
          _summaryLine('Müşteri', customerName.isEmpty ? '-' : customerName),
          _summaryLine('Telefon', customerPhone.isEmpty ? '-' : customerPhone),
          _summaryLine('Adres', addressText.isEmpty ? '-' : addressText),
          const SizedBox(height: 8),
          const Text(
            'Ürünler:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2A44),
            ),
          ),
          const SizedBox(height: 4),
          if (lines.isEmpty)
            const Text(
              'Henüz ürün eklenmedi.',
              style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
            )
          else
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '- ${line.productName} x ${line.quantity}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475467),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          _summaryLine('Ara toplam', currencyFormat(subtotal), bold: true),
          _summaryLine('Kargo', currencyFormat(shipping)),
          _summaryLine('Genel toplam', currencyFormat(total), bold: true),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: const Color(0xFF667085),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: const Color(0xFF1F2A44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
