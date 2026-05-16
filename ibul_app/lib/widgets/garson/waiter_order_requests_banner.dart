import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../services/waiter_order_request_service.dart';

/// Garson modülünde bekleyen (doğrulanmamış QR) müşteri istekleri.
class WaiterOrderRequestsBanner extends StatelessWidget {
  const WaiterOrderRequestsBanner({super.key, required this.sellerId});

  final String sellerId;

  @override
  Widget build(BuildContext context) {
    if (sellerId.trim().isEmpty) return const SizedBox.shrink();
    final service = WaiterOrderRequestService();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: service.pendingRequestsStream(sellerId),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows.map((r) => _RequestCard(row: r)).toList(growable: false),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.row});

  final Map<String, dynamic> row;

  String _text(dynamic v) => (v ?? '').toString().trim();

  Future<void> _approve(BuildContext context) async {
    final id = _text(row['id']);
    if (id.isEmpty) return;
    final service = WaiterOrderRequestService();
    try {
      await service.approveRequest(requestId: id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İstek onaylandı; sipariş ve yazdırma oluşturuldu.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Onay başarısız: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reject(BuildContext context) async {
    final id = _text(row['id']);
    if (id.isEmpty) return;
    final controller = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İsteği reddet'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Red nedeni (isteğe bağlı)',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    try {
      await WaiterOrderRequestService().rejectRequest(
        requestId: id,
        reason: reason,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İstek reddedildi.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Red başarısız: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editAndApprove(BuildContext context) async {
    final id = _text(row['id']);
    if (id.isEmpty) return;
    final raw = row['items_draft'];
    List<dynamic> list;
    if (raw is List) {
      list = List<dynamic>.from(raw);
    } else {
      try {
        list = jsonDecode(jsonEncode(raw)) as List<dynamic>? ?? [];
      } catch (_) {
        list = [];
      }
    }
    final controllers = <TextEditingController>[];
    for (var i = 0; i < list.length; i++) {
      final m = Map<String, dynamic>.from(list[i] as Map);
      final q = (m['quantity'] as num?)?.toInt() ?? 1;
      controllers.add(TextEditingController(text: '$q'));
    }
    final edited = await showDialog<List<Map<String, dynamic>>?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Düzenle ve onayla'),
          content: SizedBox(
            width: 420,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (_, i) {
                final m = Map<String, dynamic>.from(list[i] as Map);
                final name = _text(m['name'] ?? m['item_name']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name.isEmpty ? 'Kalem ${i + 1}' : name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: TextField(
                          controller: controllers[i],
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Adet',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                final out = <Map<String, dynamic>>[];
                for (var i = 0; i < list.length; i++) {
                  final m = Map<String, dynamic>.from(list[i] as Map);
                  final q = int.tryParse(controllers[i].text.trim()) ??
                      ((m['quantity'] as num?)?.toInt() ?? 1);
                  m['quantity'] = q.clamp(1, 999);
                  out.add(m);
                }
                Navigator.pop(ctx, out);
              },
              child: const Text('Onayla'),
            ),
          ],
        );
      },
    );
    for (final c in controllers) {
      c.dispose();
    }
    if (edited == null) return;
    try {
      await WaiterOrderRequestService().approveRequest(
        requestId: id,
        editedItems: edited,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Düzenlenmiş istek onaylandı.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Onay başarısız: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tableNo = (row['table_number'] as num?)?.toInt() ?? 0;
    final notes = _text(row['customer_notes']);
    final items = row['items_draft'];
    String itemsPreview = '';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      itemsPreview = encoder.convert(items);
      if (itemsPreview.length > 420) {
        itemsPreview = '${itemsPreview.substring(0, 420)}…';
      }
    } catch (_) {
      itemsPreview = items.toString();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFFFF7ED),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.orange.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2_outlined, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'QR onayı bekliyor · Masa $tableNo',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
                Chip(
                  label: const Text('Bekliyor'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.orange.shade100,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Müşteri seçimleri (taslak):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              itemsPreview.isEmpty ? '—' : itemsPreview,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Not: $notes', style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _approve(context),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Onayla ve siparişe çevir'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _editAndApprove(context),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Düzenle ve onayla'),
                ),
                TextButton.icon(
                  onPressed: () => _reject(context),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Reddet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
