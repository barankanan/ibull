import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../domain/coupon_campaign.dart';
import '../domain/coupon_enums.dart';
import '../domain/coupon_status_labels.dart';
import 'coupon_status_chip.dart';

enum WheelRewardPickerFilter {
  all,
  ibul,
  seller,
  sellerWheel,
  discounts,
}

class RewardWheelAddRewardSheet extends StatefulWidget {
  const RewardWheelAddRewardSheet({
    required this.coupons,
    required this.selectedIds,
    super.key,
  });

  final List<CouponCampaign> coupons;
  final Set<String> selectedIds;

  @override
  State<RewardWheelAddRewardSheet> createState() =>
      _RewardWheelAddRewardSheetState();
}

class _RewardWheelAddRewardSheetState extends State<RewardWheelAddRewardSheet> {
  final _search = TextEditingController();
  WheelRewardPickerFilter _filter = WheelRewardPickerFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CouponCampaign> get _visible {
    final q = _search.text.trim().toLowerCase();
    return widget.coupons.where((coupon) {
      final matchesFilter = switch (_filter) {
        WheelRewardPickerFilter.all => true,
        WheelRewardPickerFilter.ibul =>
          coupon.sourceType == CouponSourceType.ibul,
        WheelRewardPickerFilter.seller =>
          coupon.sourceType == CouponSourceType.seller,
        WheelRewardPickerFilter.sellerWheel => coupon.wheelRequested,
        WheelRewardPickerFilter.discounts =>
          coupon.discountType == CouponDiscountType.percent ||
              coupon.discountType == CouponDiscountType.fixed,
      };
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;
      return coupon.name.toLowerCase().contains(q) ||
          coupon.code.toLowerCase().contains(q) ||
          (coupon.storeName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ödül Ekle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Kupon, kod veya mağaza ara',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in [
                      (WheelRewardPickerFilter.all, 'Tüm Kuponlar'),
                      (WheelRewardPickerFilter.ibul, 'İBUL Kuponları'),
                      (WheelRewardPickerFilter.seller, 'Satıcı Kuponları'),
                      (
                        WheelRewardPickerFilter.sellerWheel,
                        'Satıcı Hediye Çarkı Teklifleri',
                      ),
                      (WheelRewardPickerFilter.discounts, 'İndirimler'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(entry.$2),
                          selected: _filter == entry.$1,
                          selectedColor: AppColors.softPurple,
                          onSelected: (_) => setState(() => _filter = entry.$1),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Eşleşen kupon bulunamadı.'))
                    : ListView.separated(
                        controller: controller,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final coupon = items[index];
                          final already = widget.selectedIds.contains(coupon.id);
                          return ListTile(
                            dense: true,
                            enabled: !already &&
                                coupon.approvalStatus ==
                                    CouponApprovalStatus.approved,
                            title: Text(coupon.name),
                            subtitle: Text(
                              [
                                coupon.code,
                                coupon.discountLabel,
                                coupon.storeName ?? CouponStatusLabels.source(coupon.sourceType),
                                CouponStatusLabels.effective(coupon.effectiveStatus),
                              ].join(' • '),
                            ),
                            trailing: already
                                ? const Text('Çarkta')
                                : CouponStatusChip(status: coupon.effectiveStatus),
                            onTap: already
                                ? null
                                : coupon.approvalStatus ==
                                      CouponApprovalStatus.approved
                                ? () => Navigator.pop(context, coupon)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
