import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../services/auth_service.dart';
import '../services/support_service.dart';

class CancelAppealPage extends StatefulWidget {
  const CancelAppealPage({
    super.key,
    required this.notificationData,
    required this.notificationBody,
  });

  final Map<String, dynamic> notificationData;
  final String notificationBody;

  @override
  State<CancelAppealPage> createState() => _CancelAppealPageState();
}

class _CancelAppealPageState extends State<CancelAppealPage> {
  final TextEditingController _appealController = TextEditingController();
  final AuthService _authService = AuthService();
  final SupportService _supportService = SupportService();
  bool _requestReorder = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _appealController.dispose();
    super.dispose();
  }

  String _textFromData(String key, {String fallback = '-'}) {
    final value = widget.notificationData[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  String _resolveCancelReason() {
    final fromData =
        widget.notificationData['cancel_reason']?.toString().trim() ?? '';
    if (fromData.isNotEmpty) return fromData;

    final body = widget.notificationBody;
    final regex = RegExp(r'[Ss]ebep[:\s]+(.+)$');
    final match = regex.firstMatch(body);
    if (match != null) {
      final value = (match.group(1) ?? '').trim();
      if (value.isNotEmpty) return value;
    }
    return 'Belirtilmedi';
  }

  Future<void> _submitAppeal() async {
    final userId = _authService.currentUser?.id.trim() ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İtiraz için önce giriş yapmalısınız.')),
      );
      return;
    }

    final appealText = _appealController.text.trim();
    if (appealText.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen itiraz nedenini en az 10 karakter yazın.'),
        ),
      );
      return;
    }

    final storeName = _textFromData('store_name', fallback: 'Mağaza');
    final productName = _textFromData('product_name', fallback: 'Ürün');
    final orderId = _textFromData('order_id');
    final orderItemId = _textFromData('order_item_id');
    final trackingNumber = _textFromData('tracking_number');
    final cancelReason = _resolveCancelReason();

    final subject = 'İptal İtirazı - $storeName / $productName';
    final description = [
      'Kullanıcı iptal kararına itiraz etti.',
      '',
      'Mağaza: $storeName',
      'Ürün: $productName',
      'Sipariş No: $orderId',
      'Sipariş Kalemi: $orderItemId',
      'Takip Kodu: $trackingNumber',
      'İptal Nedeni: $cancelReason',
      'Tekrar Sipariş Talebi: ${_requestReorder ? 'Evet' : 'Hayır'}',
      '',
      'İtiraz Metni:',
      appealText,
    ].join('\n');
    final nowIso = DateTime.now().toUtc().toIso8601String();
    String? nullIfDash(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == '-') return null;
      return trimmed;
    }

    setState(() => _isSubmitting = true);
    try {
      final client = Supabase.instance.client;
      final normalizedOrderItemId = nullIfDash(orderItemId);
      final normalizedOrderId = nullIfDash(orderId);
      final normalizedTracking = nullIfDash(trackingNumber);

      if (normalizedOrderItemId != null ||
          normalizedOrderId != null ||
          normalizedTracking != null) {
        try {
          final rows = await client
              .from('user_notifications')
              .select('id, data')
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(500);
          for (final raw in (rows as List<dynamic>)) {
            final map = Map<String, dynamic>.from(raw as Map);
            final dataRaw = map['data'];
            final data = dataRaw is Map
                ? dataRaw.map((k, v) => MapEntry(k.toString(), v))
                : <String, dynamic>{};
            final type = data['type']?.toString().trim().toLowerCase() ?? '';
            if (type != 'cancel_appeal_submitted') continue;
            final rowOrderItemId =
                data['order_item_id']?.toString().trim() ?? '';
            final rowOrderId = data['order_id']?.toString().trim() ?? '';
            final rowTracking =
                data['tracking_number']?.toString().trim() ?? '';
            final sameItem =
                normalizedOrderItemId != null &&
                rowOrderItemId.isNotEmpty &&
                rowOrderItemId == normalizedOrderItemId;
            final sameOrder =
                normalizedOrderId != null &&
                rowOrderId.isNotEmpty &&
                rowOrderId == normalizedOrderId;
            final sameTracking =
                normalizedTracking != null &&
                rowTracking.isNotEmpty &&
                rowTracking == normalizedTracking;
            if (sameItem || sameOrder || sameTracking) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bu sipariş için itiraz zaten gönderilmiş.'),
                ),
              );
              Navigator.of(context).pop(false);
              return;
            }
          }
        } catch (e) {
          debugPrint('CancelAppealPage duplicate check warn: $e');
        }
      }

      try {
        await _supportService.createTicket(
          userId: userId,
          userType: 'user',
          category: 'Sipariş İtirazı',
          subject: subject,
          description: description,
          priority: _requestReorder
              ? TicketPriority.high
              : TicketPriority.medium,
        );
      } catch (e) {
        // Destek tablosu yoksa bile itirazı seller/user notification ile
        // kaybetmiyoruz; akış devam eder.
        debugPrint('CancelAppealPage support ticket warn: $e');
      }
      String sellerId = '';
      if (normalizedOrderItemId != null) {
        try {
          final itemRow = await client
              .from('order_items')
              .select('seller_id')
              .eq('id', normalizedOrderItemId)
              .maybeSingle();
          if (itemRow != null) {
            sellerId = (itemRow['seller_id']?.toString().trim() ?? '').trim();
          }
        } catch (e) {
          debugPrint('CancelAppealPage seller lookup warn: $e');
        }
      }

      final commonData = <String, dynamic>{
        'order_id': nullIfDash(orderId),
        'order_item_id': nullIfDash(orderItemId),
        'tracking_number': nullIfDash(trackingNumber),
        'store_name': nullIfDash(storeName),
        'product_name': nullIfDash(productName),
        'cancel_reason': nullIfDash(cancelReason),
        'appeal_text': appealText,
        'request_reorder': _requestReorder,
        'submitted_at': nowIso,
      };

      if (sellerId.isNotEmpty) {
        final sellerBody = _requestReorder
            ? 'Kurye siparişi iptal etti. Müşteri itiraz edip siparişin tekrar gönderilmesini istedi.'
            : '$storeName siparişindeki iptal kararına müşteri itiraz etti.';
        await client.from('user_notifications').insert({
          'user_id': sellerId,
          'title': 'İptal İtirazı',
          'body': sellerBody,
          'data': {
            'type': 'cancel_appeal_received',
            'status': 'cancel_appeal_received',
            'appeal_status': 'Yeni',
            'buyer_user_id': userId,
            ...commonData,
            'open_tab': 'support',
          },
          'created_at': nowIso,
        });
      }

      await client.from('user_notifications').insert({
        'user_id': userId,
        'title': storeName,
        'body': 'İtiraz gönderildi. Talebiniz satıcıya iletildi.',
        'data': {
          'type': 'cancel_appeal_submitted',
          'status': 'cancel_appeal_submitted',
          ...commonData,
          'open_tab': 'notifications',
        },
        'created_at': nowIso,
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İtiraz gönderilemedi: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeName = _textFromData('store_name', fallback: 'Mağaza');
    final productName = _textFromData('product_name', fallback: 'Ürün');
    final trackingNumber = _textFromData('tracking_number');
    final cancelReason = _resolveCancelReason();

    return Scaffold(
      appBar: AppBar(title: const Text('İptal İtirazı'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE6E9EF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  productName,
                  style: const TextStyle(
                    color: Color(0xFF475467),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Takip: $trackingNumber',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'İptal Nedeni: $cancelReason',
                  style: const TextStyle(
                    color: Color(0xFFB42318),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'İtiraz açıklaması',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _appealController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText:
                  'İptalin neden hatalı olduğunu ve teslimin devam etmesini neden istediğinizi yazın.',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE6E9EF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE6E9EF)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            value: _requestReorder,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Tekrar sipariş talebim var',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'İtirazınız incelenirken yeniden teslimat talebiniz de iletilir.',
            ),
            onChanged: _isSubmitting
                ? null
                : (value) => setState(() => _requestReorder = value),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitAppeal,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gavel_rounded),
              label: Text(_isSubmitting ? 'Gönderiliyor...' : 'İtirazı Gönder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
