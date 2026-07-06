import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_image_cdn.dart';
import '../../core/app_motion.dart';
import '../../core/app_state.dart';
import '../../core/cart_add_diagnostics.dart';
import '../../core/constants.dart';
import '../../core/interaction_feedback.dart';
import '../../core/product_purchasability_helper.dart';
import '../../core/product_rich_description.dart';
import '../../models/product_model.dart';
import '../../screens/login_page.dart';
import '../../screens/product_detail_page.dart';
import '../../services/supabase_service.dart';
import '../optimized_image.dart';
import '../premium_interactions.dart';

const double _kQuickViewWideBreakpoint = 720;
const double _kQuickViewDialogMaxWidth = 900;
const double _kQuickViewDialogMaxHeightRatio = 0.86;
const double _kQuickViewDialogCompactHeight = 600;
const int _kQuickViewMaxSpecs = 8;
const int _kQuickViewSpecMaxChars = 60;
const int _kQuickViewAboutMaxLines = 3;

@visibleForTesting
Product quickViewMergeDetailFallback(Product seed, Product detail) =>
    _QuickViewProductContent.mergeDetailFallback(seed, detail);

@visibleForTesting
String? quickViewResolveAboutText(Product product) =>
    _QuickViewProductContent.resolveAboutText(product);

@visibleForTesting
int quickViewResolveHighlightSpecCount(Product product) =>
    _QuickViewProductContent.resolveHighlightSpecs(product).length;

@visibleForTesting
bool quickViewIsInternalSpecKey(String key) =>
    _QuickViewProductContent.isInternalSpecKey(key);

@visibleForTesting
bool quickViewIsInternalSpecValue(String? value) =>
    _QuickViewProductContent.isInternalSpecValue(value);

/// Opens quick view as a centered dialog on wide screens, bottom sheet on mobile.
Future<void> showProductQuickView(
  BuildContext context, {
  required Product product,
  bool forceFoodOrderButton = false,
  String source = 'unknown',
}) {
  final isWide = MediaQuery.sizeOf(context).width >= _kQuickViewWideBreakpoint;
  if (isWide) {
    final viewSize = MediaQuery.sizeOf(context);
    final maxDialogHeight = (viewSize.height * _kQuickViewDialogMaxHeightRatio)
        .clamp(_kQuickViewDialogCompactHeight, 720.0);
    return showAppDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 24,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _kQuickViewDialogMaxWidth,
              maxHeight: maxDialogHeight,
              minHeight: 420,
            ),
            child: ProductQuickViewPanel(
              product: product,
              forceFoodOrderButton: forceFoodOrderButton,
              layout: ProductQuickViewLayout.desktop,
              source: source,
              onClose: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        );
      },
    );
  }

  return showAppModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    isScrollControlled: true,
    builder: (sheetContext) {
      return ProductQuickInfoSheet(
        product: product,
        forceFoodOrderButton: forceFoodOrderButton,
        source: source,
      );
    },
  );
}

enum ProductQuickViewLayout { mobileSheet, desktop }

/// Mobile bottom-sheet shell around [ProductQuickViewPanel].
class ProductQuickInfoSheet extends StatelessWidget {
  const ProductQuickInfoSheet({
    super.key,
    required this.product,
    this.forceFoodOrderButton = false,
    this.source = 'unknown',
  });

  final Product product;
  final bool forceFoodOrderButton;
  final String source;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.74,
        minChildSize: 0.48,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 24,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: ProductQuickViewPanel(
              product: product,
              forceFoodOrderButton: forceFoodOrderButton,
              layout: ProductQuickViewLayout.mobileSheet,
              scrollController: scrollController,
              source: source,
              onClose: () => Navigator.of(context).pop(),
            ),
          );
        },
      ),
    );
  }
}

class ProductQuickViewPanel extends StatefulWidget {
  const ProductQuickViewPanel({
    super.key,
    required this.product,
    required this.layout,
    required this.onClose,
    this.scrollController,
    this.forceFoodOrderButton = false,
    this.source = 'unknown',
  });

  final Product product;
  final ProductQuickViewLayout layout;
  final VoidCallback onClose;
  final ScrollController? scrollController;
  final bool forceFoodOrderButton;
  final String source;

  @override
  State<ProductQuickViewPanel> createState() => _ProductQuickViewPanelState();
}

class _ProductQuickViewPanelState extends State<ProductQuickViewPanel> {
  late Product _displayProduct;
  bool _loadingDetail = false;
  bool _detailFetchStarted = false;

  @override
  void initState() {
    super.initState();
    _displayProduct = widget.product;
    _logInitialState();
    _maybeFetchDetailFallback();
  }

  bool get _isDesktop => widget.layout == ProductQuickViewLayout.desktop;

  bool get _isFoodCategory {
    final category = (_displayProduct.category ?? '').toLowerCase();
    final subCategory = (_displayProduct.subCategory ?? '').toLowerCase();
    return widget.forceFoodOrderButton ||
        category.contains('yemek') ||
        subCategory.contains('yemek');
  }

  bool get _hasDiscount =>
      _displayProduct.oldPrice != null &&
      _displayProduct.oldPrice!.trim().isNotEmpty;

  List<_QuickViewSpec> get _highlightSpecs =>
      _QuickViewProductContent.resolveHighlightSpecs(_displayProduct);

  String? get _aboutText =>
      _QuickViewProductContent.resolveAboutText(_displayProduct);

  void _logInitialState() {
    final productId = _displayProduct.productId?.trim() ?? '';
    QuickViewDiagnostics.log(
      'open productId=${productId.isEmpty ? 'none' : productId} '
      'source=${widget.source}',
      key: 'open:$productId',
    );
    QuickViewDiagnostics.log(
      'initial description empty=${_QuickViewProductContent.resolveAboutText(_displayProduct) == null}',
      key: 'init-desc:$productId',
    );
    QuickViewDiagnostics.log(
      'initial specs empty=${_QuickViewProductContent.resolveHighlightSpecs(_displayProduct).isEmpty}',
      key: 'init-specs:$productId',
    );
    final aboutSource = _QuickViewProductContent.resolveAboutSource(_displayProduct);
    QuickViewDiagnostics.log(
      'about source=$aboutSource',
      key: 'about-src:$productId',
    );
    final specsSource = _QuickViewProductContent.resolveSpecsSource(_displayProduct);
    QuickViewDiagnostics.log(
      'specs source=$specsSource specs count=${_highlightSpecs.length}',
      key: 'specs-src:$productId',
    );
  }

  Future<void> _maybeFetchDetailFallback() async {
    if (_detailFetchStarted) return;
    _detailFetchStarted = true;

    final productId = _displayProduct.productId?.trim() ?? '';
    if (productId.isEmpty) {
      QuickViewDiagnostics.log(
        'detail fallback skipped reason=missing_product_id',
        key: 'fallback-skip:$productId',
      );
      return;
    }

    final hasAbout = _aboutText != null;
    final hasSpecs = _highlightSpecs.isNotEmpty;
    if (hasAbout && hasSpecs) {
      QuickViewDiagnostics.log(
        'detail fallback skipped reason=already_has_content',
        key: 'fallback-skip:$productId',
      );
      return;
    }

    QuickViewDiagnostics.log(
      'detail fallback start productId=$productId',
      key: 'fallback-start:$productId',
    );
    if (mounted) {
      setState(() => _loadingDetail = true);
    }

    try {
      final db = await SupabaseService.instance.getProductQuickViewDetail(
        productId,
      );
      if (!mounted) return;

      if (db == null) {
        setState(() => _loadingDetail = false);
        QuickViewDiagnostics.log(
          'detail fallback error=empty_response',
          key: 'fallback-empty:$productId',
        );
        return;
      }

      final detailProduct = Product.fromDBProduct(db);
      setState(() {
        _displayProduct = _QuickViewProductContent.mergeDetailFallback(
          _displayProduct,
          detailProduct,
        );
        _loadingDetail = false;
      });

      final aboutEmpty = _QuickViewProductContent.resolveAboutText(_displayProduct) == null;
      final specsCount =
          _QuickViewProductContent.resolveHighlightSpecs(_displayProduct).length;
      QuickViewDiagnostics.log(
        'detail fallback success descriptionEmpty=$aboutEmpty specsCount=$specsCount',
        key: 'fallback-ok:$productId',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingDetail = false);
      QuickViewDiagnostics.log(
        'detail fallback error=${error.runtimeType}',
        key: 'fallback-err:$productId',
      );
    }
  }

  List<_MetaChipData> get _metaChips {
    final chips = <_MetaChipData>[];
    final category = _displayProduct.displayCategory;
    if (category != null) {
      chips.add(_MetaChipData(icon: Icons.category_outlined, label: category));
    }
    if (_displayProduct.brand.trim().isNotEmpty) {
      chips.add(
        _MetaChipData(
          icon: Icons.storefront_outlined,
          label: _displayProduct.brand,
        ),
      );
    }
    if (_displayProduct.stock != null) {
      final stock = _displayProduct.stock!;
      chips.add(
        _MetaChipData(
          icon: stock > 0 ? Icons.check_circle_outline : Icons.info_outline,
          label: stock > 0 ? 'Stokta ($stock)' : 'Stok yok',
          tone: stock > 0 ? _MetaChipTone.positive : _MetaChipTone.warning,
        ),
      );
    }
    final prep = _displayProduct.displayPreparationTime;
    if (prep != null) {
      chips.add(
        _MetaChipData(
          icon: Icons.schedule_outlined,
          label:
              '${_displayProduct.displayPreparationTimeLabel ?? 'Hazırlanma'}: $prep',
        ),
      );
    }
    return chips;
  }

  Widget _buildDetailLoadingRow() {
    return const Padding(
      padding: EdgeInsets.only(top: 16),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Ürün bilgileri yükleniyor…',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Ürün Hakkında'),
        const SizedBox(height: 8),
        Text(
          text,
          maxLines: _kQuickViewAboutMaxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.55,
            color: Color(0xFF4B5563),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _openProductDetail(BuildContext context) {
    InteractionFeedback.forInteraction(InteractionFeedbackType.mainCta);
    Navigator.of(context).pop();
    Navigator.of(context).push(
      buildAppPageRoute<void>(
        builder: (_) => ProductDetailPage(
          product: _displayProduct,
          openSource: 'quick_view',
        ),
      ),
    );
  }

  Future<void> _handlePrimaryAction(BuildContext context) async {
    if (_isFoodCategory) {
      _openProductDetail(context);
      return;
    }
    final appState = context.read<AppState>();
    if (!appState.isLoggedIn) {
      _showLoginRequiredDialog(context);
      return;
    }
    InteractionFeedback.forInteraction(InteractionFeedbackType.addToCart);
    CartAddDiagnostics.tap(
      productId: _displayProduct.productId ?? '-',
      source: 'quick_view',
    );
    final messenger = ScaffoldMessenger.maybeOf(context);
    final error = await appState.addToCart(_displayProduct);
    if (error != null) {
      messenger?.showSnackBar(
        SnackBar(content: Text(error), duration: const Duration(seconds: 2)),
      );
      return;
    }
    InteractionFeedback.forInteraction(
      InteractionFeedbackType.successState,
      channel: 'cart_add_success',
    );
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Ürün sepete eklendi'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  void _showLoginRequiredDialog(BuildContext context) {
    showAppDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Giriş Yap'),
        content: const Text('Bu işlemi yapmak için giriş yapmanız gerekiyor.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).push(
                buildAppPageRoute<void>(
                  builder: (_) => const LoginPage(),
                ),
              );
            },
            child: const Text('Giriş Yap'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      return _buildDesktopLayout(context);
    }
    return _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildSheetHandle(),
        _buildMobileHeader(),
        Expanded(child: _buildScrollableBody(context)),
        _buildCtaBar(context),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 42, child: _buildDesktopImageColumn()),
        Expanded(
          flex: 58,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xFFF0F0F0)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDesktopRightHeader(),
                Expanded(child: _buildDesktopScrollableBody()),
                _buildCtaBar(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopImageColumn() {
    final imagePath =
        _displayProduct.images.isNotEmpty ? _displayProduct.images.first : '';
    final imageUrl = imagePath.isEmpty
        ? ''
        : AppImageCdn.buildUrl(imagePath, AppImageVariant.detail);

    final imageContent = imageUrl.isEmpty
        ? const _HeroFallback()
        : OptimizedImage(
            imageUrlOrPath: imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const _HeroFallback(),
          );

    return ColoredBox(
      color: const Color(0xFFF9FAFB),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340, maxHeight: 420),
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE8EAED)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Center(child: imageContent),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopRightHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Hızlı Bakış',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onClose,
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopScrollableBody() {
    final aboutText = _aboutText;
    final specs = _highlightSpecs;
    final meta = _metaChips;
    final ingredients = _displayProduct.displayIngredients;
    final serviceInfo = _displayProduct.displayServiceInfo;
    final additionalInfo = _displayProduct.displayAdditionalInfoItems;
    final hasSecondarySections = ingredients.isNotEmpty ||
        serviceInfo.isNotEmpty ||
        additionalInfo.isNotEmpty;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        hasSecondarySections ? 12 : 4,
      ),
      children: [
        _buildProductInfoBlock(desktop: true),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MetaChipRow(chips: meta),
        ],
        if (_loadingDetail &&
            aboutText == null &&
            specs.isEmpty &&
            !hasSecondarySections)
          _buildDetailLoadingRow(),
        if (aboutText != null) ...[
          const SizedBox(height: 14),
          _buildAboutSection(aboutText),
        ],
        if (specs.isNotEmpty) ...[
          const SizedBox(height: 14),
          const _SectionTitle(title: 'Öne Çıkan Özellikler'),
          const SizedBox(height: 8),
          _SpecGrid(specs: specs, desktop: true),
        ],
        if (ingredients.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionTitle(title: 'İçerik / Malzeme'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ingredients
                .take(12)
                .map((value) => _SoftTag(label: value, tone: _TagTone.warm))
                .toList(),
          ),
        ],
        if (serviceInfo.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionTitle(title: 'Servis Bilgisi'),
          const SizedBox(height: 6),
          ...serviceInfo.map((line) => _BulletLine(text: line)),
        ],
        if (additionalInfo.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionTitle(title: 'Ek Bilgiler'),
          const SizedBox(height: 6),
          ...additionalInfo.map((line) => _BulletLine(text: line)),
        ],
      ],
    );
  }

  Widget _buildSheetHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Hızlı Bakış',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onClose,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableBody(BuildContext context, {bool desktop = false}) {
    final aboutText = _aboutText;
    final specs = _highlightSpecs;
    final meta = _metaChips;
    final ingredients = _displayProduct.displayIngredients;
    final serviceInfo = _displayProduct.displayServiceInfo;
    final additionalInfo = _displayProduct.displayAdditionalInfoItems;
    final hasSecondarySections = ingredients.isNotEmpty ||
        serviceInfo.isNotEmpty ||
        additionalInfo.isNotEmpty;

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        hasSecondarySections ? 16 : 8,
      ),
      children: [
        if (!desktop) ...[
          _buildImageSection(),
          const SizedBox(height: 20),
        ],
        _buildProductInfoBlock(),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 14),
          _MetaChipRow(chips: meta),
        ],
        if (_loadingDetail &&
            aboutText == null &&
            specs.isEmpty &&
            !hasSecondarySections)
          _buildDetailLoadingRow(),
        if (aboutText != null) ...[
          const SizedBox(height: 18),
          _buildAboutSection(aboutText),
        ],
        if (specs.isNotEmpty) ...[
          const SizedBox(height: 18),
          const _SectionTitle(title: 'Öne Çıkan Özellikler'),
          const SizedBox(height: 10),
          _SpecGrid(specs: specs),
        ],
        if (ingredients.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(title: 'İçerik / Malzeme'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ingredients
                .take(12)
                .map((value) => _SoftTag(label: value, tone: _TagTone.warm))
                .toList(),
          ),
        ],
        if (serviceInfo.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(title: 'Servis Bilgisi'),
          const SizedBox(height: 8),
          ...serviceInfo.map((line) => _BulletLine(text: line)),
        ],
        if (additionalInfo.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(title: 'Ek Bilgiler'),
          const SizedBox(height: 8),
          ...additionalInfo.map((line) => _BulletLine(text: line)),
        ],
      ],
    );
  }

  Widget _buildProductInfoBlock({bool desktop = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _displayProduct.name,
          style: TextStyle(
            fontSize: desktop ? 21 : 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
            height: 1.2,
            letterSpacing: desktop ? -0.3 : -0.2,
          ),
        ),
        if (_displayProduct.brand.trim().isNotEmpty &&
            (_displayProduct.store?.trim().isEmpty ?? true)) ...[
          SizedBox(height: desktop ? 5 : 6),
          Text(
            _displayProduct.brand,
            style: TextStyle(
              fontSize: desktop ? 12.5 : 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
        if (_displayProduct.store?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: 4),
          Text(
            _displayProduct.store!.trim(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
        SizedBox(height: desktop ? 12 : 14),
        _PriceBlock(
          currentPrice: _displayProduct.displayPricingText,
          oldPrice: _hasDiscount ? _displayProduct.oldPrice : null,
          hasDiscount: _hasDiscount,
          compact: desktop,
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    final imagePath =
        _displayProduct.images.isNotEmpty ? _displayProduct.images.first : '';
    final imageUrl = imagePath.isEmpty
        ? ''
        : AppImageCdn.buildUrl(imagePath, AppImageVariant.detail);

    final imageContent = imageUrl.isEmpty
        ? const _HeroFallback()
        : OptimizedImage(
            imageUrlOrPath: imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const _HeroFallback(),
          );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 240,
          width: double.infinity,
          child: imageContent,
        ),
      ),
    );
  }

  /// Yemek/servis dışı ürünler için satın alınabilirlik değerlendirmesi.
  /// Yemek akışında "Sipariş Ver" davranışı bozulmadan korunur.
  ProductPurchasability get _purchasability =>
      ProductPurchasabilityHelper.evaluate(_displayProduct);

  Widget _buildCtaBar(BuildContext context) {
    final purchasability = _purchasability;
    final isBlocked = !_isFoodCategory && purchasability.isDefinitivelyBlocked;
    final primaryLabel = _isFoodCategory
        ? 'Sipariş Ver'
        : (isBlocked
            ? (ProductPurchasabilityHelper.blockedButtonLabel(purchasability) ??
                ProductPurchasabilityHelper.notForSaleLabel)
            : 'Sepete Ekle');
    return Container(
      padding: EdgeInsets.fromLTRB(
        _isDesktop ? 20 : 20,
        12,
        _isDesktop ? 20 : 20,
        _isDesktop ? 16 : 16 + MediaQuery.paddingOf(context).bottom,
      ),
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
      child: Row(
        children: [
          Expanded(
            child: PremiumPressable(
              child: OutlinedButton(
                onPressed: () => _openProductDetail(context),
                style: premiumButtonInteractionStyle(
                  OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  overlayColor: AppColors.primary,
                ),
                child: const Text(
                  'Ürünü İncele',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PremiumPressable(
              child: ElevatedButton(
                onPressed: isBlocked
                    ? null
                    : () => _handlePrimaryAction(context),
                style: premiumButtonInteractionStyle(
                  ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFEDEDED),
                    disabledForegroundColor: const Color(0xFF9E9E9E),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  overlayColor: Colors.white,
                ),
                child: Text(
                  primaryLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.currentPrice,
    required this.hasDiscount,
    this.oldPrice,
    this.compact = false,
  });

  final String currentPrice;
  final String? oldPrice;
  final bool hasDiscount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final formattedOld = oldPrice == null
        ? null
        : (oldPrice!.contains('TL') || oldPrice!.contains('₺'))
        ? oldPrice
        : '$oldPrice TL';

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 10,
      runSpacing: 6,
      children: [
        Text(
          currentPrice,
          style: TextStyle(
            fontSize: compact ? 24 : 26,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF111827),
            height: 1,
            letterSpacing: -0.5,
          ),
        ),
        if (hasDiscount && formattedOld != null)
          Text(
            formattedOld,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFEF4444),
              decoration: TextDecoration.lineThrough,
              decorationColor: Color(0xFFEF4444),
              fontWeight: FontWeight.w600,
            ),
          ),
        if (hasDiscount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_downward, size: 12, color: Color(0xFF2E7D32)),
                SizedBox(width: 2),
                Text(
                  'İndirim',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Color(0xFF374151),
        letterSpacing: 0.1,
      ),
    );
  }
}

class _SpecGrid extends StatelessWidget {
  const _SpecGrid({required this.specs, this.desktop = false});

  final List<_QuickViewSpec> specs;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = desktop ? 2 : 2;
        final gap = desktop ? 8.0 : 10.0;
        final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: specs
              .map(
                (spec) => SizedBox(
                  width: itemWidth,
                  child: _SpecTile(spec: spec, compact: desktop),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({required this.spec, this.compact = false});

  final _QuickViewSpec spec;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 9 : 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (spec.value == null)
            Text(
              spec.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
                height: 1.25,
              ),
            )
          else ...[
            Text(
              spec.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              spec.value!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _MetaChipTone { neutral, positive, warning }

class _MetaChipData {
  const _MetaChipData({
    required this.icon,
    required this.label,
    this.tone = _MetaChipTone.neutral,
  });

  final IconData icon;
  final String label;
  final _MetaChipTone tone;
}

class _MetaChipRow extends StatelessWidget {
  const _MetaChipRow({required this.chips});

  final List<_MetaChipData> chips;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((chip) => _MetaChip(chip: chip)).toList(),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.chip});

  final _MetaChipData chip;

  Color get _foreground {
    switch (chip.tone) {
      case _MetaChipTone.positive:
        return const Color(0xFF15803D);
      case _MetaChipTone.warning:
        return const Color(0xFFB45309);
      case _MetaChipTone.neutral:
        return const Color(0xFF4B5563);
    }
  }

  Color get _background {
    switch (chip.tone) {
      case _MetaChipTone.positive:
        return const Color(0xFFECFDF3);
      case _MetaChipTone.warning:
        return const Color(0xFFFFF7ED);
      case _MetaChipTone.neutral:
        return const Color(0xFFF3F4F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, size: 14, color: _foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              chip.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TagTone { purple, warm }

class _SoftTag extends StatelessWidget {
  const _SoftTag({required this.label, this.tone = _TagTone.purple});

  final String label;
  final _TagTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = tone == _TagTone.warm
        ? (const Color(0xFFFFF7ED), const Color(0xFFB45309))
        : (AppColors.primary.withValues(alpha: 0.08), AppColors.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.$2,
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.85),
            AppColors.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: 44,
              color: Colors.white.withValues(alpha: 0.92),
            ),
            const SizedBox(height: 8),
            Text(
              'Görsel yakında',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickViewDiagnostics {
  QuickViewDiagnostics._();

  static final Map<String, DateTime> _lastLogAt = {};
  static const Duration _throttle = Duration(seconds: 2);

  static void log(String message, {String? key}) {
    if (!kDebugMode) return;
    final now = DateTime.now();
    final throttleKey = key ?? message;
    final last = _lastLogAt[throttleKey];
    if (last != null && now.difference(last) < _throttle) return;
    _lastLogAt[throttleKey] = now;
    debugPrint('[QuickView] $message');
  }
}

class _QuickViewSpec {
  const _QuickViewSpec({required this.label, this.value});

  final String label;
  final String? value;

  factory _QuickViewSpec.fromRaw(String raw) {
    final trimmed = raw.trim();
    final colonIndex = trimmed.indexOf(':');
    if (colonIndex > 0 && colonIndex < trimmed.length - 1) {
      return _QuickViewSpec(
        label: _QuickViewProductContent.truncateText(
          trimmed.substring(0, colonIndex).trim(),
        ),
        value: _QuickViewProductContent.truncateText(
          trimmed.substring(colonIndex + 1).trim(),
        ),
      );
    }
    return _QuickViewSpec(
      label: _QuickViewProductContent.truncateText(trimmed),
    );
  }

  String get dedupeKey => '${label.toLowerCase()}|${value?.toLowerCase() ?? ''}';
}

class _QuickViewProductContent {
  const _QuickViewProductContent._();

  static const Set<String> _internalSpecKeys = {
    '_ibul_product_type',
    'ibul_product_type',
    'service_template',
    'product_template',
    'template',
    'product_type',
    'seller_id',
    'store_id',
    'user_id',
    'id',
    'uuid',
    'created_at',
    'updated_at',
    'approval_status',
    'admin_approval_status',
    'status',
    'is_active',
    'image_url',
    'image_urls',
    'imageurl',
    'video_url',
    'video_path',
    'thumbnail_path',
    'catalog_status',
    'pricing_mode',
    'pricing_type',
    'variant_group_id',
    'description_story_json',
    'rich_description',
    'richdescription',
    'features',
    'feature',
    'ozellikler',
    'özellikler',
    'description',
    'short_description',
    'shortdescription',
    'aciklama',
    'ingredients',
    'ingredient_list',
    'icerik',
    'içerik',
    'malzeme',
    'malzemeler',
    'additional_info',
    'additionalinfo',
    'notes',
    'notlar',
    'sunum',
  };

  static const Set<String> _internalSpecValues = {
    'service_template',
    'product_template',
    'template',
    'portion',
    'weight',
    'base_only',
    'pending',
    'approved',
    'rejected',
    'draft',
    'active',
    'inactive',
  };

  @visibleForTesting
  static bool isInternalSpecKey(String key) {
    final normalized = key.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (normalized.startsWith('_')) return true;
    if (_internalSpecKeys.contains(normalized)) return true;
    if (normalized.endsWith('_id')) return true;
    if (normalized.endsWith('_url')) return true;
    if (normalized.endsWith('_status')) return true;
    if (normalized.contains('_template')) return true;
    if (normalized.contains('approval')) return true;
    if (RegExp(r'^[0-9a-f-]{36}$').hasMatch(normalized)) return true;
    return false;
  }

  @visibleForTesting
  static bool isInternalSpecValue(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return false;
    if (_internalSpecValues.contains(normalized)) return true;
    if (normalized.contains('_template')) return true;
    if (RegExp(r'^[0-9a-f-]{36}$').hasMatch(normalized)) return true;
    return false;
  }

  static bool _isUserFacingSpec(_QuickViewSpec spec) {
    if (isInternalSpecKey(spec.label)) return false;
    if (isInternalSpecValue(spec.value)) return false;
    if (spec.value != null && isInternalSpecKey(spec.value!)) return false;
    return true;
  }

  @visibleForTesting
  static Product mergeDetailFallback(Product seed, Product detail) {
    return seed.copyWith(
      description: _preferNonEmpty(seed.description, detail.description),
      shortDescription: _preferNonEmpty(
        seed.shortDescription,
        detail.shortDescription,
      ),
      specifications: _preferNonEmpty(
        seed.specifications,
        detail.specifications,
      ),
      features: seed.displayFeatures.isNotEmpty
          ? seed.features
          : detail.features,
      attributes: seed.displayFeatures.isNotEmpty
          ? seed.attributes
          : detail.attributes,
      category: _preferNonEmpty(seed.category, detail.category),
      subCategory: _preferNonEmpty(seed.subCategory, detail.subCategory),
      stock: seed.stock ?? detail.stock,
    );
  }

  static String? _preferNonEmpty(String? primary, String? fallback) {
    if (primary != null && primary.trim().isNotEmpty) return primary.trim();
    if (fallback != null && fallback.trim().isNotEmpty) return fallback.trim();
    return null;
  }

  static String resolveAboutSource(Product product) {
    final richBlocks = product.displayRichDescriptionBlocks;
    if (richBlocks.isNotEmpty &&
        richDescriptionPlainText(richBlocks).trim().isNotEmpty) {
      return 'richDescription';
    }
    if (product.shortDescription?.trim().isNotEmpty == true) {
      return 'shortDescription';
    }
    if (product.description?.trim().isNotEmpty == true) {
      return 'description';
    }
    if (product.displayFullDescription != null) {
      return 'displayFullDescription';
    }
    return 'none';
  }

  static String resolveSpecsSource(Product product) {
    if (product.displayFeatures.isNotEmpty) {
      if (product.features?.isNotEmpty == true) return 'features';
      if (product.attributes?.isNotEmpty == true) return 'attributes';
      return 'displayFeatures';
    }
    if (_specsFromSpecifications(product).isNotEmpty) {
      return 'specifications';
    }
    return 'none';
  }

  static String? resolveAboutText(Product product) {
    final richBlocks = product.displayRichDescriptionBlocks;
    if (richBlocks.isNotEmpty) {
      final richPlain = richDescriptionPlainText(richBlocks);
      final cleaned = _cleanPlainText(richPlain);
      if (cleaned != null) return cleaned;
    }

    final short = product.displayShortDescription;
    if (short != null) {
      final cleaned = _cleanPlainText(short);
      if (cleaned != null) return cleaned;
    }

    final full = product.displayFullDescription;
    if (full != null) {
      return _cleanPlainText(full);
    }

    return null;
  }

  static List<_QuickViewSpec> resolveHighlightSpecs(Product product) {
    final seen = <String>{};
    final items = <_QuickViewSpec>[];

    void add(_QuickViewSpec spec) {
      if (!_isUserFacingSpec(spec)) return;
      if (spec.label.trim().isEmpty) return;
      final key = spec.dedupeKey;
      if (seen.contains(key)) return;
      seen.add(key);
      items.add(spec);
    }

    for (final raw in product.displayFeatures) {
      add(_QuickViewSpec.fromRaw(raw));
      if (items.length >= _kQuickViewMaxSpecs) {
        return items;
      }
    }

    for (final spec in _specsFromSpecifications(product)) {
      add(spec);
      if (items.length >= _kQuickViewMaxSpecs) {
        return items;
      }
    }

    if (items.isEmpty) {
      final prep = product.displayPreparationInfoText;
      if (prep != null) add(_QuickViewSpec.fromRaw(prep));
      final weight = product.displayWeightInfo;
      if (weight != null) {
        add(_QuickViewSpec(label: 'Ağırlık', value: truncateText(weight)));
      }
      final service = product.displayServiceControlInfo;
      if (service != null) {
        add(_QuickViewSpec(label: 'Seçim', value: truncateText(service)));
      }
    }

    return items.take(_kQuickViewMaxSpecs).toList(growable: false);
  }

  static List<_QuickViewSpec> _specsFromSpecifications(Product product) {
    final raw = product.specifications?.trim() ?? '';
    if (raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];

      final items = <_QuickViewSpec>[];
      for (final entry in decoded.entries) {
        final label = entry.key.toString().trim();
        if (label.isEmpty || isInternalSpecKey(label)) continue;
        final value = entry.value;
        if (value == null) continue;
        if (value is Map || value is List) continue;
        final text = truncateText(value.toString().trim());
        if (text.isEmpty || isInternalSpecValue(text)) continue;
        items.add(_QuickViewSpec(label: label, value: text));
      }
      return items;
    } catch (_) {
      return const [];
    }
  }

  static String? _cleanPlainText(String? value) {
    final stripped = stripHtml(value);
    if (stripped == null) return null;
    return truncateText(stripped, maxChars: 220);
  }

  static String? stripHtml(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final withoutTags = trimmed.replaceAll(RegExp(r'<[^>]*>'), ' ');
    final normalized = withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String truncateText(String value, {int maxChars = _kQuickViewSpecMaxChars}) {
    final trimmed = value.trim();
    if (trimmed.length <= maxChars) return trimmed;
    return '${trimmed.substring(0, maxChars - 1).trim()}…';
  }
}
