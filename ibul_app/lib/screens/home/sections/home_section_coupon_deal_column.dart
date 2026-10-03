import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/home_data_diagnostics.dart';
import '../../../widgets/optimized_image.dart';
import '../../../features/coupon/data/coupon_repository.dart';
import '../../../features/coupon/domain/coupon_campaign.dart';
import '../../../features/coupon/domain/coupon_models.dart';
import '../../../features/coupon/screens/customer/coupon_discover_page.dart';
import '../../../features/coupon/screens/customer/daily_deals_page.dart';
import '../../../models/product_model.dart';
import '../../../screens/home_lazy_routes.dart';
import '../../../widgets/skeleton_loading.dart';
import '../../coupons_page.dart';

/// Sağ sütun: Günün Fırsatı + Kupon alanı (legacy görünüm, gerçek veri).
class HomeCouponDealColumn extends StatefulWidget {
  const HomeCouponDealColumn({super.key, this.repository});

  final CouponRepository? repository;

  @override
  State<HomeCouponDealColumn> createState() => _HomeCouponDealColumnState();
}

class _HomeCouponDealColumnState extends State<HomeCouponDealColumn> {
  late final _repo = widget.repository ?? CouponRepository();
  List<DailyDealProduct> _deals = const [];
  List<UserCoupon> _coupons = const [];
  List<CouponCampaign> _discoverable = const [];
  bool _loadingDeals = true;
  String? _dealsError;
  bool _loadingCoupons = true;
  int _dealIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => Future.wait([_loadDeals(), _loadCoupons()]);

  Future<void> _loadDeals() async {
    setState(() {
      _loadingDeals = true;
      _dealsError = null;
    });
    HomeSectionDiagnostics.loading(section: 'daily_deals');
    try {
      final deals = await _repo
          .listDailyDeals(limit: 8)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _deals = deals;
        _dealIndex = 0;
        _loadingDeals = false;
      });
      HomeSectionDiagnostics.state(
        section: 'daily_deals',
        state: deals.isEmpty ? 'empty' : 'content',
        count: deals.length,
      );
    } catch (error, stack) {
      debugPrint('[HomeCouponDealColumn] daily deals failed: $error');
      debugPrintStack(stackTrace: stack);
      HomeSectionDiagnostics.state(section: 'daily_deals', state: 'error');
      if (!mounted) return;
      setState(() {
        _dealsError = 'Günün fırsatı yüklenemedi.';
        _loadingDeals = false;
      });
    }
  }

  Future<void> _loadCoupons() async {
    try {
      final coupons = await _repo.listMine().timeout(
        const Duration(seconds: 8),
      );
      final usable = coupons.where((c) => c.isUsable).toList();
      if (!mounted) return;
      setState(() {
        _coupons = usable;
        _loadingCoupons = usable.isEmpty;
      });
      if (usable.isEmpty) await _loadDiscoverableCoupons();
    } catch (error) {
      debugPrint('[HomeCouponDealColumn] my coupons failed: $error');
      await _loadDiscoverableCoupons();
    }
  }

  Future<void> _loadDiscoverableCoupons() async {
    try {
      final discoverable = await _repo.listDiscoverable().timeout(
        const Duration(seconds: 8),
      );
      if (!mounted) return;
      setState(() {
        _discoverable = discoverable;
        _loadingCoupons = false;
      });
    } catch (error) {
      debugPrint('[HomeCouponDealColumn] discoverable coupons failed: $error');
      if (mounted) setState(() => _loadingCoupons = false);
    }
  }

  String get _couponSubtitle {
    if (_loadingCoupons) return 'Kuponların yükleniyor...';
    if (_coupons.isNotEmpty) {
      final campaign = _coupons.first.campaign;
      return '${campaign?.name ?? campaign?.code ?? 'Kupon'} hazır';
    }
    if (_discoverable.isNotEmpty) {
      final first = _discoverable.first;
      return _discoverable.length == 1
          ? '${first.name} • ${first.discountLabel}'
          : '${_discoverable.length} kupon seni bekliyor • ${first.name}';
    }
    return 'Sepette kullanabileceğin kuponları gör';
  }

  DailyDealProduct? get _currentDeal =>
      _deals.isEmpty ? null : _deals[_dealIndex % _deals.length];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: _loadingDeals
              ? const SkeletonLoading(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 12,
                )
              : _currentDeal != null
              ? _buildDealCard()
              : _dealsError != null
              ? _buildDealErrorCard()
              : _buildDealEmptyCard(),
        ),
        const SizedBox(height: 12),
        Expanded(flex: 3, child: _buildCouponCard()),
      ],
    );
  }

  Widget _buildDealErrorCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Günün fırsatı yüklenemedi.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loadDeals,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Tekrar dene'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealEmptyCard() {
    return const Material(
      color: Colors.white,
      borderRadius: BorderRadius.all(Radius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Günün Fırsatı',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 8),
            Text('Şu anda yayında fırsat bulunmuyor.'),
          ],
        ),
      ),
    );
  }

  void _openDeal(DailyDealProduct deal) {
    HomeLazyRoutes.openProductDetail(
      context,
      Product(
        productId: deal.id,
        name: deal.name,
        brand: deal.brand ?? '',
        price: '${deal.discountPrice.toStringAsFixed(0)} TL',
        oldPrice: '${deal.price.toStringAsFixed(0)} TL',
        rating: 0,
        reviewCount: 0,
        tags: const ['indirim'],
        images: [if ((deal.imageUrl ?? '').isNotEmpty) deal.imageUrl!],
        store: deal.storeName,
        sellerId: deal.sellerId,
      ),
    );
  }

  Widget _buildDealCard() {
    if (_loadingDeals) {
      return const SkeletonLoading(
        width: double.infinity,
        height: double.infinity,
        borderRadius: 16,
      );
    }
    final deal = _currentDeal!;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openDeal(deal),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Günün Fırsatı',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DailyDealsPage(),
                      ),
                    ),
                    child: const Text(
                      'Tümünü Gör',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  children: [
                    if ((deal.imageUrl ?? '').isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: OptimizedImage(
                          imageUrlOrPath: deal.imageUrl!,
                            width: 72,
                            height: 72,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        deal.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${deal.discountPrice.toStringAsFixed(0)} TL',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          '${deal.price.toStringAsFixed(0)} TL',
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openDeal(deal),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('İncele'),
                  ),
                  if (_deals.length > 1)
                    IconButton(
                      tooltip: 'Sonraki fırsat',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(
                        () => _dealIndex = (_dealIndex + 1) % _deals.length,
                      ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCouponCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const CouponsPage()));
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFE082)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kuponlarım',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _couponSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63)),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CouponDiscoverPage(),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Icon(
                      Icons.confirmation_number_outlined,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Kuponları Keşfet',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget buildHomeCouponDealColumn() => const HomeCouponDealColumn();

/// Placeholder while deferred chunk loads.
Widget buildHomeCouponDealColumnSkeleton() {
  return Column(
    children: [
      Expanded(
        child: SkeletonLoading(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 16,
        ),
      ),
      const SizedBox(height: 12),
      SkeletonLoading(width: double.infinity, height: 108, borderRadius: 16),
    ],
  );
}
