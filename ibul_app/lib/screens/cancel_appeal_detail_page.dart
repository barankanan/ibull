import 'package:flutter/material.dart';

class CancelAppealDetailPage extends StatelessWidget {
  const CancelAppealDetailPage({
    super.key,
    required this.data,
    this.explanationOnly = false,
  });

  final Map<String, dynamic> data;
  final bool explanationOnly;

  String _text(String key, {String fallback = '-'}) {
    final value = data[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  String _yesNo(dynamic value) {
    if (value is bool) return value ? 'Evet' : 'Hayır';
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text == 'true' || text == '1' || text == 'evet') return 'Evet';
    if (text == 'false' || text == '0' || text == 'hayır') return 'Hayır';
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final appealText = _text('appeal_text');
    if (explanationOnly) {
      return Scaffold(
        appBar: AppBar(title: const Text('İtiraz Edildi'), centerTitle: true),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              title: 'Gönderdiğiniz açıklama',
              children: [
                Text(
                  appealText,
                  style: const TextStyle(
                    color: Color(0xFF344054),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final submittedAtRaw = _text('submitted_at', fallback: '');
    final submittedAt = submittedAtRaw.isEmpty
        ? '-'
        : (DateTime.tryParse(submittedAtRaw)?.toLocal().toString() ??
              submittedAtRaw);

    return Scaffold(
      appBar: AppBar(title: const Text('İtiraz Detayı'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            children: [
              _row('Durum', 'İtiraz gönderildi'),
              _row('Mağaza', _text('store_name')),
              _row('Ürün', _text('product_name')),
              _row('Sipariş No', _text('order_id')),
              _row('Sipariş Kalemi', _text('order_item_id')),
              _row('Takip Kodu', _text('tracking_number')),
              _row('İptal Nedeni', _text('cancel_reason')),
              _row('Tekrar sipariş talebi', _yesNo(data['request_reorder'])),
              _row('Gönderim Zamanı', submittedAt),
            ],
          ),
          const SizedBox(height: 12),
          _card(
            title: 'Gönderdiğiniz itiraz metni',
            children: [
              Text(
                appealText,
                style: const TextStyle(color: Color(0xFF344054), height: 1.45),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card({String? title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E9EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF101828),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
