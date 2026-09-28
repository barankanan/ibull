import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../screens/login_page.dart';
import '../../../../widgets/web_header.dart';
import '../../../../widgets/web_sticky_footer_scroll_view.dart';
import '../../data/coupon_repository.dart';
import '../../domain/coupon_campaign.dart';
import '../../domain/coupon_status_labels.dart';

class CouponDiscoverPage extends StatefulWidget {
  const CouponDiscoverPage({super.key});

  @override
  State<CouponDiscoverPage> createState() => _CouponDiscoverPageState();
}

class _CouponDiscoverPageState extends State<CouponDiscoverPage> {
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
      final rows = await _repo.listDiscoverable();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Kuponlar yüklenemedi.';
        _loading = false;
      });
    }
  }

  Future<void> _claim(CouponCampaign campaign) async {
    try {
      await _repo.claim(campaign.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${campaign.code} kuponu eklendi.')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = '$error'.contains('not authenticated')
          ? 'Kupon almak için giriş yapın.'
          : '$error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      if (message.contains('giriş')) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;
    final body = _loading
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
        ? const Center(child: Text('Şu anda keşfedilecek kupon yok.'))
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _items[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${item.discountLabel} • ${item.code}',
                            style: const TextStyle(color: AppColors.primary),
                          ),
                          Text(
                            [
                              CouponStatusLabels.source(item.sourceType),
                              if ((item.storeName ?? '').isNotEmpty) item.storeName!,
                              CouponStatusLabels.scope(item.scopeType),
                            ].join(' • '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () => _claim(item),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text('Al'),
                    ),
                  ],
                ),
              );
            },
          );

    if (!isWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kuponları Keşfet')),
        body: body,
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(onSearch: (q) {}),
          Expanded(child: WebStickyFooterScrollView(child: SizedBox(height: 800, child: body))),
        ],
      ),
    );
  }
}
