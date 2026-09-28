import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../core/mobile_category_catalog.dart';
import '../../../../models/db_category.dart';
import '../../../../models/seller_product.dart';
import '../../../../services/admin_service.dart';
import '../../../../services/store_service.dart';
import '../../data/coupon_repository.dart';
import '../../domain/coupon_campaign.dart';
import '../../domain/coupon_enums.dart';
import '../../domain/coupon_helpers.dart';
import '../../widgets/coupon_scope_picker.dart';

class SellerCouponAdPage extends StatefulWidget {
  const SellerCouponAdPage({
    required this.sellerId,
    this.existing,
    this.forWheel = false,
    super.key,
  });

  final String sellerId;
  final CouponCampaign? existing;
  final bool forWheel;

  @override
  State<SellerCouponAdPage> createState() => _SellerCouponAdPageState();
}

class _SellerCouponAdPageState extends State<SellerCouponAdPage> {
  final _repo = CouponRepository();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _percent = TextEditingController(text: '10');
  final _fixed = TextEditingController(text: '50');
  final _maxDiscount = TextEditingController();
  final _minCart = TextEditingController();
  final _quota = TextEditingController(text: '100');
  final _perUser = TextEditingController(text: '1');
  final _budget = TextEditingController();
  final _durationDays = TextEditingController(text: '7');
  CouponDiscountType _discountType = CouponDiscountType.percent;
  CouponScopeType _scope = CouponScopeType.all;
  bool _autoCode = true;
  bool _saving = false;
  bool _loading = true;
  String? _error;
  DateTime _startsAt = DateTime.now();
  DateTime _endsAt = DateTime.now().add(const Duration(days: 7));
  List<SellerProduct> _products = const [];
  List<MobileCategoryNode> _categories = const [];
  final Set<int> _categoryIds = {};
  final Set<String> _productIds = {};

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _name.text = existing.name;
      _code.text = existing.code;
      _autoCode = false;
      _discountType = existing.discountType;
      _percent.text = existing.discountValue.toStringAsFixed(0);
      _fixed.text = existing.discountValue.toStringAsFixed(0);
      _maxDiscount.text = existing.maxDiscount?.toStringAsFixed(0) ?? '';
      _minCart.text = existing.minOrderAmount.toStringAsFixed(0);
      _quota.text = existing.totalUsageLimit?.toString() ?? '100';
      _perUser.text = existing.perUserLimit.toString();
      _budget.text = existing.adBudget?.toStringAsFixed(0) ?? '';
      _durationDays.text = existing.adDurationDays?.toString() ?? '7';
      _scope = existing.scopeType == CouponScopeType.stores
          ? CouponScopeType.all
          : existing.scopeType;
      _startsAt = existing.startsAt.toLocal();
      _endsAt = existing.endsAt.toLocal();
      _categoryIds.addAll(existing.categoryIds);
      _productIds.addAll(existing.productIds);
    } else {
      _code.text = CouponCodeGenerator.generate(prefix: 'MAG');
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final products = await StoreService().getSellerProductsSnapshot();
      List<CategoryWithSubcategories> catalog = const [];
      try {
        catalog = await AdminService().getManagedCategoriesWithSubs();
      } catch (_) {}
      final usedNames = products
          .expand((p) => [p.mainCategory, p.subCategory])
          .map((name) => name.trim().toLowerCase())
          .where((name) => name.isNotEmpty)
          .toSet();
      final nodes = catalog
          .map(
            (row) => MobileCategoryNode(
              id: row.mainCategory.id,
              name: row.mainCategory.name,
              orderIndex: row.mainCategory.orderIndex,
              parentId: row.mainCategory.parentId,
              subCategories: row.subCategories
                  .where(
                    (sub) => usedNames.contains(sub.name.trim().toLowerCase()),
                  )
                  .map(
                    (sub) => MobileCategoryNode(
                      id: sub.id,
                      name: sub.name,
                      orderIndex: sub.orderIndex,
                      parentId: sub.parentId,
                    ),
                  )
                  .toList(),
            ),
          )
          .where(
            (node) =>
                usedNames.contains(node.name.trim().toLowerCase()) ||
                node.subCategories.isNotEmpty,
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _products = products;
        _categories = nodes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Mağaza bilgileri yüklenemedi.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _percent.dispose();
    _fixed.dispose();
    _maxDiscount.dispose();
    _minCart.dispose();
    _quota.dispose();
    _perUser.dispose();
    _budget.dispose();
    _durationDays.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      _toast('Kampanya adı zorunludur.');
      return;
    }
    final discountValue = _discountType == CouponDiscountType.percent
        ? double.tryParse(_percent.text) ?? 0.0
        : _discountType == CouponDiscountType.fixed
        ? double.tryParse(_fixed.text) ?? 0.0
        : 0.0;
    if (_discountType != CouponDiscountType.freeShipping && discountValue <= 0) {
      _toast('Geçerli bir indirim miktarı girin.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.upsert(
        CouponCampaign(
          id: widget.existing?.id ?? '',
          name: _name.text.trim(),
          code: _autoCode
              ? CouponCodeGenerator.generate(prefix: 'MAG')
              : CouponCodeGenerator.normalize(_code.text),
          sourceType: CouponSourceType.couponAd,
          discountType: _discountType,
          discountValue: discountValue,
          maxDiscount: double.tryParse(_maxDiscount.text),
          minOrderAmount: double.tryParse(_minCart.text) ?? 0.0,
          totalUsageLimit: int.tryParse(_quota.text),
          perUserLimit: int.tryParse(_perUser.text) ?? 1,
          scopeType: _scope == CouponScopeType.all
              ? CouponScopeType.stores
              : _scope,
          sellerId: widget.sellerId,
          storeId: widget.sellerId,
          storeIds: [widget.sellerId],
          approvalStatus: CouponApprovalStatus.pendingReview,
          wheelRequested: widget.forWheel || (widget.existing?.wheelRequested ?? false),
          adBudget: double.tryParse(_budget.text),
          adDurationDays: int.tryParse(_durationDays.text),
          startsAt: _startsAt.toUtc(),
          endsAt: _endsAt.toUtc(),
          categoryIds: _categoryIds.toList(),
          productIds: _productIds.toList(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      _toast('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.forWheel || (widget.existing?.wheelRequested ?? false)
              ? 'Hediye Çarkı Reklamı'
              : 'Kupon Reklamı',
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if ((widget.existing?.rejectionReason ?? '').isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Red sebebi: ${widget.existing!.rejectionReason}',
                    ),
                  ),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Kampanya adı'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final type in [
                      CouponDiscountType.percent,
                      CouponDiscountType.fixed,
                      CouponDiscountType.freeShipping,
                    ])
                      ChoiceChip(
                        label: Text(
                          type == CouponDiscountType.percent
                              ? '% indirim'
                              : type == CouponDiscountType.fixed
                              ? 'TL indirim'
                              : 'Ücretsiz teslimat',
                        ),
                        selected: _discountType == type,
                        selectedColor: AppColors.softPurple,
                        onSelected: (_) => setState(() => _discountType = type),
                      ),
                  ],
                ),
                if (_discountType == CouponDiscountType.percent) ...[
                  TextField(
                    controller: _percent,
                    decoration: const InputDecoration(labelText: 'Yüzde'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: _maxDiscount,
                    decoration: const InputDecoration(
                      labelText: 'Maksimum indirim (TL)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                if (_discountType == CouponDiscountType.fixed)
                  TextField(
                    controller: _fixed,
                    decoration: const InputDecoration(labelText: 'TL tutarı'),
                    keyboardType: TextInputType.number,
                  ),
                TextField(
                  controller: _minCart,
                  decoration: const InputDecoration(labelText: 'Minimum sepet'),
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kupon kodunu otomatik oluştur'),
                  value: _autoCode,
                  onChanged: (value) => setState(() => _autoCode = value),
                ),
                if (!_autoCode)
                  TextField(
                    controller: _code,
                    decoration: const InputDecoration(labelText: 'Kupon kodu'),
                    textCapitalization: TextCapitalization.characters,
                  ),
                TextField(
                  controller: _quota,
                  decoration: const InputDecoration(
                    labelText: 'Kullanım adedi / kota',
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: _perUser,
                  decoration: const InputDecoration(
                    labelText: 'Kullanıcı başına limit',
                  ),
                  keyboardType: TextInputType.number,
                ),
                if (widget.forWheel ||
                    (widget.existing?.wheelRequested ?? false)) ...[
                  TextField(
                    controller: _durationDays,
                    decoration: const InputDecoration(
                      labelText: 'Reklam süresi (gün)',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final days = int.tryParse(value);
                      if (days == null || days <= 0) return;
                      setState(() {
                        _endsAt = _startsAt.add(Duration(days: days));
                      });
                    },
                  ),
                  TextField(
                    controller: _budget,
                    decoration: const InputDecoration(
                      labelText: 'Reklam bütçesi (TL)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Kuponun uygulanacağı alan',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                CouponScopePicker(
                  scope: _scope.dbValue == 'stores' ? 'all' : _scope.dbValue,
                  onScopeChanged: (value) => setState(
                    () => _scope = value == 'all'
                        ? CouponScopeType.all
                        : CouponScopeTypeParser.fromDb(value),
                  ),
                  categories: _categories,
                  selectedCategoryIds: _categoryIds,
                  onToggleCategory: (id) {
                    setState(() {
                      if (_categoryIds.contains(id)) {
                        _categoryIds.remove(id);
                      } else {
                        _categoryIds.add(id);
                      }
                    });
                  },
                  products: _products,
                  selectedProductIds: _productIds,
                  onToggleProduct: (id) {
                    setState(() {
                      if (_productIds.contains(id)) {
                        _productIds.remove(id);
                      } else {
                        _productIds.add(id);
                      }
                    });
                  },
                  allowAllIbul: false,
                  allowStores: false,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Başlangıç'),
                  subtitle: Text(_startsAt.toLocal().toString()),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startsAt,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => _startsAt = date);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bitiş'),
                  subtitle: Text(_endsAt.toLocal().toString()),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endsAt,
                      firstDate: _startsAt,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(
                        () => _endsAt = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          23,
                          59,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    _saving
                        ? 'Gönderiliyor...'
                        : 'Admin onayına gönder',
                  ),
                ),
              ],
            ),
    );
  }
}
