import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../data/coupon_repository.dart';
import '../../domain/coupon_campaign.dart';
import '../../domain/coupon_status_labels.dart';
import '../../widgets/coupon_status_chip.dart';
import 'seller_coupon_ad_page.dart';

class SellerCouponAdHubPage extends StatefulWidget {
  const SellerCouponAdHubPage({
    required this.sellerId,
    this.forWheel = false,
    super.key,
  });

  final String sellerId;
  final bool forWheel;

  @override
  State<SellerCouponAdHubPage> createState() => _SellerCouponAdHubPageState();
}

class _SellerCouponAdHubPageState extends State<SellerCouponAdHubPage> {
  final _repo = CouponRepository();
  bool _loading = true;
  String? _error;
  List<CouponCampaign> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repo.listForSeller(widget.sellerId);
      if (!mounted) return;
      setState(() {
        _items = widget.forWheel
            ? rows.where((item) => item.wheelRequested).toList()
            : rows;
        _loading = false;
      });
    } catch (error, stack) {
      debugPrint('SellerCouponAdHubPage.load failed: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _error = 'Kupon reklamları yüklenemedi.';
        _loading = false;
      });
    }
  }

  Future<void> _openForm([CouponCampaign? existing]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SellerCouponAdPage(
          sellerId: widget.sellerId,
          existing: existing,
          forWheel: widget.forWheel,
        ),
      ),
    );
    if (saved == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reklamınız admin onayına gönderildi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.forWheel ? 'Hediye Çarkı Reklamı' : 'Kupon Reklamı'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        actions: [
          TextButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Yeni'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  OutlinedButton(onPressed: _load, child: const Text('Tekrar dene')),
                ],
              ),
            )
          : _items.isEmpty
          ? Center(
              child: Text(
                widget.forWheel
                    ? 'Henüz hediye çarkı teklifi yok.'
                    : 'Henüz kupon reklamı yok.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      [
                        item.code,
                        item.discountLabel,
                        CouponStatusLabels.effective(item.effectiveStatus),
                        if ((item.rejectionReason ?? '').isNotEmpty)
                          'Red: ${item.rejectionReason}',
                      ].join(' • '),
                    ),
                    trailing: CouponStatusChip(status: item.effectiveStatus),
                    onTap: () => _openForm(item),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: Text(widget.forWheel ? 'Hediye Çarkında Yer Al' : 'Kupon Reklamı'),
      ),
    );
  }
}
