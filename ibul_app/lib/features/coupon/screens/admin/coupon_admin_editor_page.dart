import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../core/mobile_category_catalog.dart';
import '../../../../models/db_category.dart';
import '../../../../services/admin_service.dart';
import '../../data/coupon_repository.dart';
import '../../domain/coupon_campaign.dart';
import '../../domain/coupon_enums.dart';
import '../../domain/coupon_helpers.dart';
import '../../widgets/coupon_scope_picker.dart';

class CouponAdminEditorPage extends StatefulWidget {
  const CouponAdminEditorPage({this.existing, super.key});

  final CouponCampaign? existing;

  @override
  State<CouponAdminEditorPage> createState() => _CouponAdminEditorPageState();
}

class _CouponAdminEditorPageState extends State<CouponAdminEditorPage> {
  final _repo = CouponRepository();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _code = TextEditingController();
  final _percent = TextEditingController(text: '10');
  final _fixed = TextEditingController(text: '50');
  final _maxDiscount = TextEditingController();
  final _minCart = TextEditingController();
  final _perUser = TextEditingController(text: '1');
  final _quota = TextEditingController();
  CouponDiscountType _discountType = CouponDiscountType.percent;
  CouponScopeType _scope = CouponScopeType.all;
  bool _newUsersOnly = false;
  bool _isPublic = true;
  bool _autoCode = true;
  bool _saving = false;
  DateTime _startsAt = DateTime.now();
  DateTime _endsAt = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    23,
    59,
  );
  final Set<int> _categoryIds = {};
  List<MobileCategoryNode> _categories = const [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _name.text = existing.name;
      _description.text = existing.description ?? '';
      _code.text = existing.code;
      _autoCode = false;
      _discountType = existing.discountType;
      _percent.text = existing.discountValue.toStringAsFixed(0);
      _fixed.text = existing.discountValue.toStringAsFixed(0);
      _maxDiscount.text = existing.maxDiscount?.toStringAsFixed(0) ?? '';
      _minCart.text = existing.minOrderAmount > 0
          ? existing.minOrderAmount.toStringAsFixed(0)
          : '';
      _perUser.text = existing.perUserLimit.toString();
      _quota.text = existing.totalUsageLimit?.toString() ?? '';
      _scope = existing.scopeType;
      _newUsersOnly = existing.newUsersOnly;
      _isPublic = existing.isPublic;
      _startsAt = existing.startsAt.toLocal();
      _endsAt = existing.endsAt.toLocal();
      _categoryIds.addAll(existing.categoryIds);
    } else {
      _code.text = CouponCodeGenerator.generate();
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await AdminService().getManagedCategoriesWithSubs();
      if (!mounted) return;
      setState(() {
        _categories = rows
            .map(
              (CategoryWithSubcategories row) => MobileCategoryNode(
                id: row.mainCategory.id,
                name: row.mainCategory.name,
                orderIndex: row.mainCategory.orderIndex,
                parentId: row.mainCategory.parentId,
                imageUrl: row.mainCategory.imageUrl,
                isActive: row.mainCategory.isActive,
                subCategories: row.subCategories
                    .map(
                      (sub) => MobileCategoryNode(
                        id: sub.id,
                        name: sub.name,
                        orderIndex: sub.orderIndex,
                        parentId: sub.parentId,
                        imageUrl: sub.imageUrl,
                        isActive: sub.isActive,
                      ),
                    )
                    .toList(),
              ),
            )
            .toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _code.dispose();
    _percent.dispose();
    _fixed.dispose();
    _maxDiscount.dispose();
    _minCart.dispose();
    _perUser.dispose();
    _quota.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool start}) async {
    final initial = start ? _startsAt : _endsAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (start) {
        _startsAt = value;
      } else {
        _endsAt = value;
      }
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _toast('Kupon adı zorunludur.');
      return;
    }
    final code = _autoCode
        ? CouponCodeGenerator.generate()
        : CouponCodeGenerator.normalize(_code.text);
    if (code.isEmpty) {
      _toast('Kupon kodu girin veya otomatik oluşturun.');
      return;
    }
    final discountValue = _discountType == CouponDiscountType.percent
        ? double.tryParse(_percent.text.replaceAll(',', '.')) ?? 0.0
        : _discountType == CouponDiscountType.fixed
        ? double.tryParse(_fixed.text.replaceAll(',', '.')) ?? 0.0
        : 0.0;
    if (_discountType != CouponDiscountType.freeShipping && discountValue <= 0) {
      _toast('Geçerli bir indirim değeri girin.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.upsert(
        CouponCampaign(
          id: widget.existing?.id ?? '',
          name: _name.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          code: code,
          sourceType: widget.existing?.sourceType ?? CouponSourceType.ibul,
          discountType: _discountType,
          discountValue: discountValue,
          maxDiscount: double.tryParse(_maxDiscount.text.replaceAll(',', '.')),
          minOrderAmount:
              double.tryParse(_minCart.text.replaceAll(',', '.')) ?? 0.0,
          perUserLimit: int.tryParse(_perUser.text) ?? 1,
          totalUsageLimit: int.tryParse(_quota.text),
          newUsersOnly: _newUsersOnly,
          isPublic: _isPublic,
          scopeType: _scope,
          sellerId: widget.existing?.sellerId,
          storeId: widget.existing?.storeId,
          storeIds: widget.existing?.storeIds ?? const [],
          approvalStatus: CouponApprovalStatus.approved,
          wheelRequested: widget.existing?.wheelRequested ?? false,
          adBudget: widget.existing?.adBudget,
          adDurationDays: widget.existing?.adDurationDays,
          startsAt: _startsAt.toUtc(),
          endsAt: _endsAt.toUtc(),
          categoryIds: _categoryIds.toList(),
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
      backgroundColor: const Color(0xFFFAF9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F1035),
        title: Text(widget.existing == null ? 'Yeni Kupon' : 'Kuponu Düzenle'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kaydet'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _section('Kupon Bilgileri', [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Kupon adı'),
            ),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Açıklama'),
              maxLines: 2,
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
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Kupon kodu'),
              ),
          ]),
          _section('İndirim Türü', [
            Wrap(
              spacing: 8,
              children: [
                for (final type in CouponDiscountType.values)
                  ChoiceChip(
                    label: Text(
                      type == CouponDiscountType.percent
                          ? 'Yüzde indirim'
                          : type == CouponDiscountType.fixed
                          ? 'Sabit tutar'
                          : type == CouponDiscountType.freeShipping
                          ? 'Ücretsiz teslimat'
                          : 'Özel kampanya',
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
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Yüzde'),
              ),
              TextField(
                controller: _maxDiscount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maksimum indirim tutarı (TL)',
                ),
              ),
            ],
            if (_discountType == CouponDiscountType.fixed)
              TextField(
                controller: _fixed,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'TL tutarı'),
              ),
          ]),
          _section('Kuponun Geçerli Olduğu Alan', [
            CouponScopePicker(
              scope: _scope.dbValue,
              onScopeChanged: (value) =>
                  setState(() => _scope = CouponScopeTypeParser.fromDb(value)),
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
            ),
          ]),
          _section('Kullanım Koşulları', [
            TextField(
              controller: _minCart,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minimum sepet tutarı'),
            ),
            TextField(
              controller: _perUser,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kullanıcı başına kullanım limiti',
              ),
            ),
            TextField(
              controller: _quota,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Toplam kullanım kotası'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Yeni kullanıcılara özel'),
              value: _newUsersOnly,
              onChanged: (value) => setState(() => _newUsersOnly = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Herkese açık'),
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
            ),
          ]),
          _section('Yayın Süresi', [
            Wrap(
              spacing: 8,
              children: [
                for (final preset in CouponSchedulePresets.forLocalNow(
                  DateTime.now(),
                ))
                  ActionChip(
                    label: Text(preset.label),
                    onPressed: () => setState(() {
                      _startsAt = preset.startsAt;
                      _endsAt = preset.endsAt;
                    }),
                  ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Başlangıç'),
              subtitle: Text(_fmt(_startsAt)),
              onTap: () => _pickDateTime(start: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bitiş'),
              subtitle: Text(_fmt(_endsAt)),
              onTap: () => _pickDateTime(start: false),
            ),
          ]),
        ],
      ),
    );
  }

  String _fmt(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF1F1035),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
