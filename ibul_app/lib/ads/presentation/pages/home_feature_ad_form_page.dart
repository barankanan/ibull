import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/home_feature_ad_helper.dart';
import '../../models/home_card_template.dart';
import '../../services/home_card_template_service.dart';
import '../../services/home_feature_ad_service.dart';
import '../../../services/admin_service.dart';
import '../../../services/store_service.dart';
import '../widgets/home_feature_ad_budget_sections.dart';
import '../widgets/home_feature_ad_form_sections.dart';
import '../widgets/home_feature_ad_preview_panel.dart';

class HomeFeatureAdFormPage extends StatefulWidget {
  const HomeFeatureAdFormPage({
    required this.sellerId,
    super.key,
  });

  final String sellerId;

  @override
  State<HomeFeatureAdFormPage> createState() => _HomeFeatureAdFormPageState();
}

class _HomeFeatureAdFormPageState extends State<HomeFeatureAdFormPage> {
  final _templateService = HomeCardTemplateService();
  final _adService = HomeFeatureAdService();
  final _storeService = StoreService();

  final _campaignNameController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _dailyBudgetController = TextEditingController(text: '150');
  final _totalBudgetController = TextEditingController(text: '2100');
  final _campaignNoteController = TextEditingController();

  List<HomeCardTemplate> _templates = [];
  HomeCardTemplate? _selectedTemplate;
  List<String> _bannerUrls = [];
  List<String> _selectedProductIds = [];
  List<Map<String, dynamic>> _storeProducts = [];
  List<String> _storeBannerOptions = [];
  String _storeName = '';
  String? _storeLogoUrl;
  String? _storeId;
  DateTime _startsAt = DateTime.now();
  DateTime _endsAt = DateTime.now().add(const Duration(days: 14));
  String _budgetType = 'total';
  bool _autoCoverFirstBanner = true;
  bool _randomizeProducts = false;
  bool _rotateBanners = true;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;
  int _previewRefreshTick = 0;

  @override
  void initState() {
    super.initState();
    _productSearchController.addListener(() => setState(() {}));
    _loadInitial();
  }

  @override
  void dispose() {
    _campaignNameController.dispose();
    _productSearchController.dispose();
    _dailyBudgetController.dispose();
    _totalBudgetController.dispose();
    _campaignNoteController.dispose();
    super.dispose();
  }

  int get _durationDays {
    final days = _endsAt.difference(_startsAt).inDays + 1;
    return days > 0 ? days : 0;
  }

  double get _dailyBudget =>
      double.tryParse(_dailyBudgetController.text.replaceAll(',', '.')) ?? 0;

  double get _totalBudget {
    if (_budgetType == 'daily') {
      return _dailyBudget * _durationDays;
    }
    return double.tryParse(_totalBudgetController.text.replaceAll(',', '.')) ??
        0;
  }

  double get _estimatedFee => _totalBudget > 0 ? _totalBudget * 1.08 : 0;

  int get _estimatedImpressions =>
      _totalBudget > 0 ? (_totalBudget * 45).round() : 0;

  List<Map<String, dynamic>> get _filteredProducts {
    final q = _productSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return _storeProducts;
    return _storeProducts.where((p) {
      final name = p['name']?.toString().toLowerCase() ?? '';
      final sub = p['sub_category']?.toString().toLowerCase() ?? '';
      return name.contains(q) || sub.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _selectedProductMaps {
    final byId = {for (final p in _storeProducts) p['id']?.toString(): p};
    return _selectedProductIds
        .map((id) => byId[id])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  String get _draftKey => 'home_feature_ad_draft_${widget.sellerId}';

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final templates = await _templateService.getActiveTemplates();
      final profile = await _storeService.getStoreProfile();
      final storeName = profile?['storeName']?.toString().trim() ?? '';
      final storeId = widget.sellerId;
      final products = await _storeService.getSellerProductsSnapshot();
      final publicInfo = await _storeService.getStorePublicInfoById(storeId);
      final banners = <String>[];
      if (publicInfo != null && publicInfo['banners'] is List) {
        banners.addAll(
          (publicInfo['banners'] as List)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty),
        );
      }
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _storeName = storeName;
        _storeId = storeId;
        _storeLogoUrl = publicInfo?['logoUrl']?.toString();
        _storeProducts = products
            .map(
              (p) => {
                'id': p.id,
                'name': p.name,
                'image_url': p.imageUrl,
                'price': p.price,
                'sub_category': p.subCategory,
              },
            )
            .toList();
        _storeBannerOptions = banners;
        _isLoading = false;
      });
      await _restoreDraft();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _campaignNameController.text =
            data['campaign_name']?.toString() ?? '';
        _bannerUrls = List<String>.from(data['banner_urls'] ?? const []);
        _selectedProductIds =
            List<String>.from(data['product_ids'] ?? const []);
        _budgetType = data['budget_type']?.toString() ?? 'total';
        _dailyBudgetController.text =
            data['daily_budget']?.toString() ?? _dailyBudgetController.text;
        _totalBudgetController.text =
            data['total_budget']?.toString() ?? _totalBudgetController.text;
        _autoCoverFirstBanner =
            data['auto_cover'] as bool? ?? _autoCoverFirstBanner;
        _randomizeProducts =
            data['randomize_products'] as bool? ?? _randomizeProducts;
        _rotateBanners = data['rotate_banners'] as bool? ?? _rotateBanners;
        _campaignNoteController.text =
            data['campaign_note']?.toString() ?? '';
        final templateId = data['template_id']?.toString();
        if (templateId != null) {
          _selectedTemplate = _templates.cast<HomeCardTemplate?>().firstWhere(
                (t) => t?.id == templateId,
                orElse: () => null,
              );
        }
        final starts = data['starts_at']?.toString();
        final ends = data['ends_at']?.toString();
        if (starts != null) _startsAt = DateTime.tryParse(starts) ?? _startsAt;
        if (ends != null) _endsAt = DateTime.tryParse(ends) ?? _endsAt;
      });
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _draftKey,
        jsonEncode({
          'campaign_name': _campaignNameController.text.trim(),
          'template_id': _selectedTemplate?.id,
          'banner_urls': _bannerUrls,
          'product_ids': _selectedProductIds,
          'starts_at': _startsAt.toIso8601String(),
          'ends_at': _endsAt.toIso8601String(),
          'budget_type': _budgetType,
          'daily_budget': _dailyBudgetController.text.trim(),
          'total_budget': _totalBudgetController.text.trim(),
          'auto_cover': _autoCoverFirstBanner,
          'randomize_products': _randomizeProducts,
          'rotate_banners': _rotateBanners,
          'campaign_note': _campaignNoteController.text.trim(),
        }),
      );
      _showSnack('Taslak kaydedildi.');
    } catch (e) {
      _showSnack('Taslak kaydedilemedi: $e');
    }
  }

  void _syncBudgetFromDaily() {
    if (_budgetType != 'daily') return;
    final total = _dailyBudget * _durationDays;
    if (total > 0) {
      _totalBudgetController.text = total.toStringAsFixed(0);
    }
    setState(() {});
  }

  void _syncBudgetFromTotal() {
    if (_budgetType != 'total') return;
    if (_durationDays > 0 && _totalBudget > 0) {
      _dailyBudgetController.text =
          (_totalBudget / _durationDays).toStringAsFixed(0);
    }
    setState(() {});
  }

  Future<void> _pickBanner() async {
    if (_bannerUrls.length >= HomeFeatureAdHelper.maxBannerImages) {
      _showSnack(
        'En fazla ${HomeFeatureAdHelper.maxBannerImages} görsel ekleyebilirsiniz.',
      );
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    try {
      final url = await AdminService().uploadCampaignImage(
        Uint8List.fromList(bytes),
        'home_feature_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (!mounted) return;
      setState(() {
        if (_bannerUrls.contains(url)) return;
        _bannerUrls = [..._bannerUrls, url];
      });
    } catch (e) {
      _showSnack('Görsel yüklenemedi: $e');
    }
  }

  void _toggleStoreBanner(String url, bool selected) {
    setState(() {
      if (selected) {
        _bannerUrls.remove(url);
      } else if (_bannerUrls.length < HomeFeatureAdHelper.maxBannerImages &&
          !_bannerUrls.contains(url)) {
        _bannerUrls = [..._bannerUrls, url];
      } else if (_bannerUrls.contains(url)) {
        return;
      } else {
        _showSnack(
          'En fazla ${HomeFeatureAdHelper.maxBannerImages} görsel seçebilirsiniz.',
        );
      }
    });
  }

  void _moveBanner(int from, int to) {
    if (from == to) return;
    setState(() {
      final next = List<String>.from(_bannerUrls);
      final item = next.removeAt(from);
      next.insert(to, item);
      _bannerUrls = next;
    });
  }

  void _toggleProduct(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedProductIds.remove(id);
      } else if (_selectedProductIds.length >=
          HomeFeatureAdHelper.maxProducts) {
        _showSnack(
          'En fazla ${HomeFeatureAdHelper.maxProducts} ürün seçebilirsiniz.',
        );
      } else {
        _selectedProductIds = [..._selectedProductIds, id];
      }
    });
  }

  void _moveProduct(int from, int to) {
    if (from == to) return;
    setState(() {
      final next = List<String>.from(_selectedProductIds);
      final item = next.removeAt(from);
      next.insert(to, item);
      _selectedProductIds = next;
    });
  }

  Map<String, dynamic> _buildExtraSettings() {
    return {
      if (_campaignNoteController.text.trim().isNotEmpty)
        'campaign_note': _campaignNoteController.text.trim(),
      'auto_cover_first_banner': _autoCoverFirstBanner,
      'randomize_products': _randomizeProducts,
      'rotate_banners': _rotateBanners,
    };
  }

  String? _resolvedCampaignName() {
    final manual = _campaignNameController.text.trim();
    if (manual.isNotEmpty) return manual;
    final templateLabel = _selectedTemplate?.displayLabel;
    if (templateLabel == null || templateLabel.isEmpty) return null;
    return '$_storeName — $templateLabel';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_selectedTemplate == null) {
      _showSnack('Kart şablonu seçmelisiniz.');
      return;
    }
    if (_storeId == null || _storeName.isEmpty) {
      _showSnack('Mağaza bilgisi bulunamadı.');
      return;
    }
    final bannerUrls =
        HomeFeatureAdHelper.uniqueOrderedIds(_bannerUrls);
    final productIds =
        HomeFeatureAdHelper.uniqueOrderedIds(_selectedProductIds);
    final issues = HomeFeatureAdHelper.validateSubmission(
      cardTemplateId: _selectedTemplate!.id,
      bannerImages: bannerUrls,
      productIds: productIds,
      startsAt: _startsAt,
      endsAt: _endsAt,
    );
    if (issues.isNotEmpty) {
      _showSnack(issues.first);
      return;
    }
    setState(() => _isSubmitting = true);
    debugPrint('[SellerAds] create_start');
    try {
      final campaign = await _adService.createHomeFeatureAd(
        sellerId: widget.sellerId,
        storeId: _storeId!,
        storeName: _storeName,
        template: _selectedTemplate!,
        bannerUrls: bannerUrls,
        productIds: productIds,
        startsAt: _startsAt,
        endsAt: _endsAt,
        campaignName: _resolvedCampaignName(),
        budgetType: _budgetType,
        dailyBudget: _budgetType == 'daily' ? _dailyBudget : 0,
        totalBudget: _totalBudget,
        extraSettings: _buildExtraSettings(),
      );
      debugPrint(
        '[SellerAds] create_success campaignId=${campaign.id}'
        ' status=${campaign.status.dbValue}',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reklamınız admin onayına gönderildi. '
            'Onaylandıktan sonra ana sayfada görünecek.',
          ),
        ),
      );
      Navigator.of(context).pop(campaign);
    } catch (e) {
      _showSnack(
        e is PostgrestException
            ? 'Reklam kaydedilemedi: ${e.message}'
            : e.toString(),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Ana Sayfada Öne Çıkar'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _buildErrorState()
              : _templates.isEmpty
                  ? _buildEmptyTemplateState()
                  : _buildFormBody(),
      bottomNavigationBar: _isLoading || _loadError != null || _templates.isEmpty
          ? null
          : _buildActionBar(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadInitial, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTemplateState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.view_carousel_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Henüz ana sayfa kart şablonu yok.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reklam oluşturmak için adminin önce kart şablonu oluşturması gerekir.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            if (_storeName.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Mağaza: $_storeName', style: const TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final formColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            HomeFeatureCampaignInfoSection(
              storeName: _storeName,
              campaignNameController: _campaignNameController,
              templates: _templates,
              selectedTemplate: _selectedTemplate,
              onTemplateChanged: (v) => setState(() => _selectedTemplate = v),
            ),
            const SizedBox(height: 16),
            HomeFeatureBannerSection(
              bannerUrls: _bannerUrls,
              storeBannerOptions: _storeBannerOptions,
              onToggleStoreBanner: _toggleStoreBanner,
              onRemoveBanner: (i) => setState(() => _bannerUrls.removeAt(i)),
              onMoveBanner: _moveBanner,
              onPickBanner: _pickBanner,
            ),
            const SizedBox(height: 16),
            HomeFeatureProductSection(
              searchController: _productSearchController,
              allProducts: _storeProducts,
              filteredProducts: _filteredProducts,
              selectedProductIds: _selectedProductIds,
              onToggleProduct: _toggleProduct,
              onMoveProduct: _moveProduct,
            ),
            const SizedBox(height: 16),
            HomeFeatureBudgetSection(
              startsAt: _startsAt,
              endsAt: _endsAt,
              durationDays: _durationDays,
              dailyBudgetController: _dailyBudgetController,
              totalBudgetController: _totalBudgetController,
              budgetType: _budgetType,
              onBudgetTypeChanged: (v) => setState(() {
                _budgetType = v;
                if (v == 'daily') {
                  _syncBudgetFromDaily();
                } else {
                  _syncBudgetFromTotal();
                }
              }),
              onStartsAtChanged: (d) => setState(() {
                _startsAt = d;
                if (_endsAt.isBefore(_startsAt)) {
                  _endsAt = _startsAt.add(const Duration(days: 14));
                }
                _syncBudgetFromDaily();
              }),
              onEndsAtChanged: (d) => setState(() {
                _endsAt = d;
                _syncBudgetFromDaily();
              }),
              onDailyBudgetChanged: _syncBudgetFromDaily,
              onTotalBudgetChanged: _syncBudgetFromTotal,
              estimatedFee: _estimatedFee,
              estimatedImpressions: _estimatedImpressions,
            ),
            const SizedBox(height: 16),
            HomeFeatureExtraSettingsSection(
              campaignNoteController: _campaignNoteController,
              autoCoverFirstBanner: _autoCoverFirstBanner,
              randomizeProducts: _randomizeProducts,
              rotateBanners: _rotateBanners,
              onAutoCoverChanged: (v) => setState(() => _autoCoverFirstBanner = v),
              onRandomizeChanged: (v) => setState(() => _randomizeProducts = v),
              onRotateChanged: (v) => setState(() => _rotateBanners = v),
            ),
            if (!wide) ...[
              const SizedBox(height: 16),
              _buildPreviewPanel(),
            ],
            const SizedBox(height: 100),
          ],
        );

        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: formColumn,
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 10, 20),
                child: formColumn,
              ),
            ),
            SizedBox(
              width: 360,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 20, 20, 20),
                child: _buildPreviewPanel(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ana Sayfada Öne Çıkar',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Mağazanızı kategori ana sayfasında banner ve seçili ürünlerle öne çıkarın.',
          style: TextStyle(color: Color(0xFF64748B), height: 1.4),
        ),
      ],
    );
  }

  Widget _buildPreviewPanel() {
    return KeyedSubtree(
      key: ValueKey(_previewRefreshTick),
      child: HomeFeatureAdPreviewPanel(
        storeName: _storeName,
        storeLogoUrl: _storeLogoUrl,
        selectedTemplate: _selectedTemplate,
        bannerUrls: _bannerUrls,
        selectedProducts: _selectedProductMaps,
        startsAt: _startsAt,
        endsAt: _endsAt,
        durationDays: _durationDays,
        dailyBudget: _budgetType == 'daily'
            ? _dailyBudget
            : (_durationDays > 0 ? _totalBudget / _durationDays : 0),
        totalBudget: _totalBudget,
        estimatedFee: _estimatedFee,
        estimatedImpressions: _estimatedImpressions,
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Reklamınız admin onayına gönderilecektir.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _saveDraft,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Taslak kaydet'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() => _previewRefreshTick++),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Önizlemeyi yenile'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_isSubmitting ? 'Gönderiliyor...' : 'Gönder'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
