import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../features/coupon/data/coupon_repository.dart';
import '../../../features/coupon/domain/coupon_models.dart';
import '../../../features/coupon/screens/customer/coupon_discover_page.dart';
import '../../../features/coupon/screens/customer/daily_deals_page.dart';
import '../../../models/product_model.dart';
import '../../../screens/home_lazy_routes.dart';
import '../../../widgets/skeleton_loading.dart';
import '../../coupons_page.dart';

/// Sağ sütun: Günün Fırsatı + Kupon alanı (legacy görünüm, gerçek veri).
class HomeCouponDealColumn extends StatefulWidget {
  const HomeCouponDealColumn({super.key});

  @override
  State<HomeCouponDealColumn> createState() => _HomeCouponDealColumnState();
}

class _HomeCouponDealColumnState extends State<HomeCouponDealColumn> {
  final _repo = CouponRepository();
  List<DailyDealProduct> _deals = const [];
  List<UserCoupon> _coupons = const [];
  bool _loadingDeals = true;
  String? _dealsError;
  bool _loadingCoupons = true;
  int _dealIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final deals = await _repo.listDailyDeals(limit: 8);
      if (mounted) {
        setState(() {
          _deals = deals;
          _loadingDeals = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dealsError = e.toString();
          _loadingDeals = false;
        });
      }
    }
    try {
      final coupons = await _repo.listMine();
      if (mounted) {
        setState(() {
          _coupons = coupons.where((c) => c.isUsable).toList();
          _loadingCoupons = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCoupons = false);
    }
  }

  DailyDealProduct? get _currentDeal =>
      _deals.isEmpty ? null : _deals[_dealIndex % _deals.length];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildDealCard()),
        const SizedBox(height: 12),
        SizedBox(height: 150, child: _buildCouponCard()),
      ],
    );
  }

  Widget _buildDealCard() {
    final deal = _currentDeal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (deal == null) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DailyDealsPage()),
            );
            return;
          }
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
              images: [
                if ((deal.imageUrl ?? '').isNotEmpty) deal.imageUrl!,
              ],
              store: deal.storeName,
              sellerId: deal.sellerId,
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.92),
                AppColors.primary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: _loadingDeals
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _dealsError != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Günün Fırsatı',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _dealsError!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                )
              : deal == null
              ? const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Günün Fırsatı',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Bugün aktif fırsat bulunmuyor.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Spacer(),
                    Icon(Icons.local_offer_outlined, color: Colors.white, size: 40),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Günün Fırsatı',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      deal.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    if ((deal.storeName ?? '').isNotEmpty)
                      Text(
                        deal.storeName!,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '${deal.price.toStringAsFixed(0)} TL',
                          style: const TextStyle(
                            color: Colors.white70,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${deal.discountPrice.toStringAsFixed(0)} TL',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        if (_deals.length > 1)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            color: Colors.white,
                            onPressed: () {
                              setState(
                                () => _dealIndex = (_dealIndex + 1) % _deals.length,
                              );
                            },
                            icon: const Icon(Icons.chevron_right),
                          ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const DailyDealsPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Tümünü Gör',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
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
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CouponsPage()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E7),
            borderRadius: BorderRadius.circular(16),
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
              const SizedBox(height: 6),
              Text(
                _loadingCoupons
                    ? 'Kuponların yükleniyor...'
                    : _coupons.isEmpty
                    ? 'Sepette kullanabileceğin kuponları gör'
                    : '${_coupons.first.campaign?.name ?? _coupons.first.campaign?.code ?? 'Kupon'} hazır',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63)),
              ),
              const Spacer(),
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
                      size: 22,
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
      SkeletonLoading(width: double.infinity, height: 150, borderRadius: 16),
    ],
  );
}
