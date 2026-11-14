import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Result of a validated adisyon line edit. The server remains the authority.
class AdisyonLineEdit {
  const AdisyonLineEdit({
    required this.quantity,
    required this.unitPrice,
    required this.priceChanged,
  });

  final int quantity;
  final double unitPrice;
  final bool priceChanged;

  double get lineTotal => quantity * unitPrice;
}

/// Why a line edit or delete must not be sent.
class AdisyonLineDenial implements Exception {
  const AdisyonLineDenial(this.message);

  final String message;

  @override
  String toString() => message;
}

final RegExp _billOrderId = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool adisyonOrderIdIsPersisted(String? orderId) {
  return _billOrderId.hasMatch((orderId ?? '').trim());
}

bool adisyonLineIsPaid(Map<String, dynamic> item) {
  if (item['paid'] == true) return true;
  final status = (item['payment_status'] ?? '').toString().toLowerCase();
  if (status == 'paid' || status == 'partial' || status == 'partially_paid') {
    return true;
  }
  final paidAmount = _asDouble(item['paid_amount'] ?? item['paidAmount']);
  return paidAmount > 0;
}

bool adisyonLineWasSentToKitchen(Map<String, dynamic> item) {
  final sentAt = (item['sent_to_kitchen_at'] ?? item['sentToKitchenAt'] ?? '')
      .toString()
      .trim();
  if (sentAt.isNotEmpty) return true;
  final status = (item['kitchen_status'] ?? item['kitchenStatus'] ?? '')
      .toString()
      .toLowerCase();
  return status == 'preparing' ||
      status == 'ready' ||
      status == 'sent' ||
      status == 'printed';
}

double? parseTurkishMoney(String raw) {
  var text = raw.trim().replaceAll('₺', '').replaceAll('TL', '').trim();
  if (text.isEmpty) return null;
  if (text.startsWith('-')) return null;
  text = text.replaceAll(' ', '');
  final hasComma = text.contains(',');
  final hasDot = text.contains('.');
  if (hasComma && hasDot) {
    if (text.lastIndexOf(',') > text.lastIndexOf('.')) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    } else {
      text = text.replaceAll(',', '');
    }
  } else if (hasComma) {
    text = text.replaceAll('.', '').replaceAll(',', '.');
  }
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) return null;
  return double.tryParse(text);
}

String formatTurkishLira(double amount) {
  final safe = amount.isFinite ? amount : 0;
  final negative = safe < 0;
  final fixed = safe.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final fromRight = whole.length - i;
    buffer.write(whole[i]);
    if (fromRight > 1 && fromRight % 3 == 1) buffer.write('.');
  }
  final sign = negative ? '-' : '';
  return '$sign₺${buffer.toString()},${parts[1]}';
}

AdisyonLineEdit planAdisyonQuantityOrPrice({
  required int currentQuantity,
  required double currentUnitPrice,
  required int nextQuantity,
  required double? nextUnitPrice,
  required bool canChangeQuantity,
  required bool canChangePrice,
  required bool linePaid,
  required double otherLinesTotal,
  required double paidAmount,
}) {
  if (linePaid) {
    throw const AdisyonLineDenial(
      'Ödemesi alınmış kalem sessizce değiştirilemez.',
    );
  }
  if (!canChangeQuantity) {
    throw const AdisyonLineDenial('Adet değiştirme yetkiniz yok.');
  }
  if (nextQuantity < 1) {
    throw const AdisyonLineDenial('Adet en az 1 olmalı. Silmek için sil simgesini kullanın.');
  }
  if (nextUnitPrice == null) {
    throw const AdisyonLineDenial('Birim fiyat sayı olarak okunamadı.');
  }
  if (nextUnitPrice < 0) {
    throw const AdisyonLineDenial('Birim fiyat negatif olamaz.');
  }
  final priceChanged = (nextUnitPrice - currentUnitPrice).abs() > 0.001;
  if (priceChanged && !canChangePrice) {
    throw const AdisyonLineDenial('Fiyat değiştirme yetkiniz yok.');
  }
  if (nextQuantity == currentQuantity && !priceChanged) {
    throw const AdisyonLineDenial('Değişiklik yok.');
  }
  final nextBill = otherLinesTotal + (nextQuantity * nextUnitPrice);
  if (paidAmount > 0 && nextBill + 0.001 < paidAmount) {
    throw const AdisyonLineDenial(
      'Yeni toplam, alınmış ödemenin altında kalamaz.',
    );
  }
  return AdisyonLineEdit(
    quantity: nextQuantity,
    unitPrice: priceChanged ? nextUnitPrice : currentUnitPrice,
    priceChanged: priceChanged,
  );
}

void planAdisyonLineRemoval({
  required bool linePaid,
  required bool canRemove,
  required double lineTotal,
  required double billTotal,
  required double paidAmount,
}) {
  if (!canRemove) {
    throw const AdisyonLineDenial('Ürün silme yetkiniz yok.');
  }
  if (linePaid) {
    throw const AdisyonLineDenial(
      'Ödemesi alınmış kalem sessizce silinemez.',
    );
  }
  final nextBill = billTotal - lineTotal;
  if (paidAmount > 0 && nextBill + 0.001 < paidAmount) {
    throw const AdisyonLineDenial(
      'Silince kalan toplam, alınmış ödemenin altında kalır.',
    );
  }
}

double _asDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 0;
}

Future<AdisyonLineEdit?> showAdisyonLineEditor({
  required BuildContext context,
  required String productName,
  required int quantity,
  required double unitPrice,
  required bool canChangePrice,
}) {
  return showDialog<AdisyonLineEdit>(
    context: context,
    builder: (dialogContext) {
      return _AdisyonLineEditorDialog(
        productName: productName,
        quantity: quantity,
        unitPrice: unitPrice,
        canChangePrice: canChangePrice,
      );
    },
  );
}

class _AdisyonLineEditorDialog extends StatefulWidget {
  const _AdisyonLineEditorDialog({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.canChangePrice,
  });

  final String productName;
  final int quantity;
  final double unitPrice;
  final bool canChangePrice;

  @override
  State<_AdisyonLineEditorDialog> createState() =>
      _AdisyonLineEditorDialogState();
}

class _AdisyonLineEditorDialogState extends State<_AdisyonLineEditorDialog> {
  late int _quantity = widget.quantity;
  late final TextEditingController _price = TextEditingController(
    text: widget.unitPrice.toStringAsFixed(2).replaceAll('.', ','),
  );
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  double? get _parsedPrice => parseTurkishMoney(_price.text);

  @override
  Widget build(BuildContext context) {
    final nextPrice = _parsedPrice ?? widget.unitPrice;
    return AlertDialog(
      title: const Text('Ürünü düzenle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ürün adı', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            Text(widget.productName, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Mevcut: ${widget.quantity} adet × ${formatTurkishLira(widget.unitPrice)} = ${formatTurkishLira(widget.quantity * widget.unitPrice)}',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'Azalt',
                  onPressed: _quantity <= 1
                      ? null
                      : () => setState(() => _quantity -= 1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(
                  tooltip: 'Artır',
                  onPressed: () => setState(() => _quantity += 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const SizedBox(width: 8),
                const Text('Yeni adet'),
              ],
            ),
            TextField(
              controller: _price,
              enabled: widget.canChangePrice,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: widget.canChangePrice
                    ? 'Yeni birim fiyat'
                    : 'Birim fiyat (değiştirilemez)',
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni satır toplamı: ${formatTurkishLira(_quantity * nextPrice)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            final parsed = _parsedPrice;
            if (parsed == null) {
              setState(() => _error = 'Birim fiyat sayı olarak okunamadı.');
              return;
            }
            Navigator.pop(
              context,
              AdisyonLineEdit(
                quantity: _quantity,
                unitPrice: parsed,
                priceChanged: (parsed - widget.unitPrice).abs() > 0.001,
              ),
            );
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

Future<bool> confirmAdisyonLineRemoval(BuildContext context) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Ürünü kaldır'),
        content: const Text('Bu ürünü adisyondan kaldırmak istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ürünü Kaldır'),
          ),
        ],
      );
    },
  );
  return answer == true;
}
