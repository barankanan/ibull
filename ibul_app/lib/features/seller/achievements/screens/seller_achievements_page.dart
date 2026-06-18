import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../services/store_follow_service.dart';
import '../helpers/seller_badge_public_display.dart';
import '../models/seller_badge_models.dart';
import '../models/seller_brand_verification_models.dart';
import '../services/seller_badge_progress_resolver.dart';
import '../services/seller_brand_verification_service.dart';
import '../services/seller_featured_badge_repository.dart';
import '../widgets/seller_badge_widgets.dart';
import '../widgets/seller_brand_verification_card.dart';

typedef SellerStoreProfileNavigator = void Function(SellerStoreProfileFocus focus);

class SellerAchievementsPage extends StatefulWidget {
  const SellerAchievementsPage({
    super.key,
    required this.metrics,
    this.embedded = true,
    this.onNavigateToStoreProfile,
    this.onRetryMetrics,
  });

  final SellerBadgeStoreMetrics metrics;
  final bool embedded;
  final SellerStoreProfileNavigator? onNavigateToStoreProfile;
  final VoidCallback? onRetryMetrics;

  @override
  State<SellerAchievementsPage> createState() => _SellerAchievementsPageState();
}

class _SellerAchievementsPageState extends State<SellerAchievementsPage> {
  List<String> _featuredBadgeIds = const [];
  bool _loadingFeatured = true;
  String? _pageError;
  int _followerCount = 0;
  bool _premiumGlowActive = false;
  SellerBadgeCategory? _selectedCategory;
  final ScrollController _scrollController = ScrollController();
  Timer? _premiumGlowTimer;
  final Map<String, int> _glowReplayTokens = {};
  bool _isBrandVerified = false;
  SellerBrandVerificationApplication? _brandVerificationApplication;
  final SellerBrandVerificationService _brandVerificationService =
      SellerBrandVerificationService();
  final GlobalKey _tasksSectionKey = GlobalKey();
  final Map<SellerBadgeCategory, GlobalKey> _categoryKeys = {
    for (final category in SellerBadgeCategory.values) category: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _followerCount = widget.metrics.followerCount;
    _loadFeatured();
    _loadFollowerCount();
    _loadBrandVerification();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _premiumGlowActive = true);
      _premiumGlowTimer?.cancel();
      _premiumGlowTimer = Timer(const Duration(milliseconds: 1700), () {
        if (mounted) setState(() => _premiumGlowActive = false);
      });
    });
  }

  @override
  void dispose() {
    _premiumGlowTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SellerAchievementsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metrics.sellerId != widget.metrics.sellerId) {
      _loadFeatured();
      _loadFollowerCount();
      _loadBrandVerification();
    }
    if (oldWidget.metrics.metricsLoadFailed != widget.metrics.metricsLoadFailed &&
        !widget.metrics.metricsLoadFailed) {
      setState(() => _pageError = null);
    }
  }

  Future<void> _loadFeatured() async {
    final sellerId = widget.metrics.sellerId.trim();
    if (sellerId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _featuredBadgeIds = const [];
        _loadingFeatured = false;
      });
      return;
    }
    try {
      final ids = await SellerFeaturedBadgeRepository.instance
          .loadFeaturedBadgeIds(sellerId);
      if (!mounted) return;
      setState(() {
        _featuredBadgeIds = ids;
        _loadingFeatured = false;
        _pageError = null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[SellerAchievementsPage] featured badges load failed: $error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _loadingFeatured = false;
        _pageError = 'Vitrin rozetleri yüklenemedi';
      });
    }
  }

  Future<void> _loadBrandVerification() async {
    final sellerId = widget.metrics.sellerId.trim();
    if (sellerId.isEmpty) return;
    try {
      final verified =
          await _brandVerificationService.isSellerBrandVerified(sellerId);
      final application =
          await _brandVerificationService.fetchLatestForSeller(sellerId);
      if (!mounted) return;
      setState(() {
        _isBrandVerified = verified || widget.metrics.isBrandVerified;
        _brandVerificationApplication = application;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[SellerAchievementsPage] brand verification load failed: $error\n$stackTrace',
      );
    }
  }

  Future<void> _loadFollowerCount() async {
    final sellerId = widget.metrics.sellerId.trim();
    if (sellerId.isEmpty) return;
    try {
      final state =
          await StoreFollowService.instance.getStoreFollowState(sellerId);
      if (!mounted) return;
      setState(() => _followerCount = state.followerCount);
    } catch (error, stackTrace) {
      debugPrint(
        '[SellerAchievementsPage] follower count load failed: $error\n$stackTrace',
      );
    }
  }

  SellerBadgeStoreMetrics get _metrics {
    return SellerBadgeStoreMetrics(
      sellerId: widget.metrics.sellerId,
      followerCount: _followerCount,
      productCount: widget.metrics.productCount,
      completedOrderCount: widget.metrics.completedOrderCount,
      positiveReviewCount: widget.metrics.positiveReviewCount,
      averageRating: widget.metrics.averageRating,
      profileComplete: widget.metrics.profileComplete,
      hasLogo: widget.metrics.hasLogo,
      hasDescription: widget.metrics.hasDescription,
      hasCategory: widget.metrics.hasCategory,
      hasContactInfo: widget.metrics.hasContactInfo,
      hasRegionInfo: widget.metrics.hasRegionInfo,
      hasCoverImage: widget.metrics.hasCoverImage,
      storeCreatedAt: widget.metrics.storeCreatedAt,
      featuredBadgeIds: _featuredBadgeIds,
      metricsLoadFailed: widget.metrics.metricsLoadFailed,
      isBrandVerified: _isBrandVerified || widget.metrics.isBrandVerified,
    );
  }

  List<SellerBadgeProgress> _resolveBadges() {
    try {
      return SellerBadgeProgressResolver.resolveAll(_metrics);
    } catch (error, stackTrace) {
      debugPrint(
        '[SellerAchievementsPage] badge resolve failed: $error\n$stackTrace',
      );
      return const [];
    }
  }

  Future<void> _toggleFeatured(SellerBadgeProgress badge) async {
    if (badge.status != SellerBadgeStatus.earned) return;
    final sellerId = widget.metrics.sellerId.trim();
    if (sellerId.isEmpty) return;

    final next = List<String>.from(_featuredBadgeIds);
    final id = badge.definition.badgeId;
    if (next.contains(id)) {
      next.remove(id);
    } else {
      if (next.length >= SellerFeaturedBadgeRepository.maxProfileBadges) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profilde en fazla 4 rozet gösterebilirsin.'),
          ),
        );
        return;
      }
      next.add(id);
    }

    setState(() => _featuredBadgeIds = next);
    try {
      await SellerFeaturedBadgeRepository.instance.saveFeaturedBadgeIds(
        sellerId,
        next,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[SellerAchievementsPage] featured save failed: $error\n$stackTrace',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vitrin güncellenemedi, tekrar dene.')),
      );
    }
  }

  void _onCategorySelected(SellerBadgeCategory? category) {
    setState(() => _selectedCategory = category);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToCategory(category);
    });
  }

  void _scrollToCategory(SellerBadgeCategory? category) {
    try {
      if (!_scrollController.hasClients) return;

      if (category == null) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
        return;
      }

      final targetContext = _categoryKeys[category]?.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
        return;
      }

      final tasksContext = _tasksSectionKey.currentContext;
      if (tasksContext != null) {
        Scrollable.ensureVisible(
          tasksContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.02,
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[SellerAchievementsPage] category scroll failed: $error\n$stackTrace',
      );
    }
  }

  bool _shouldAnimateGlow(SellerBadgeProgress badge) {
    return _premiumGlowActive && badge.allowsPremiumGlow;
  }

  int _glowReplayTokenFor(String badgeId) => _glowReplayTokens[badgeId] ?? 0;

  void _replayBadgeGlow(String badgeId) {
    if (badgeId.isEmpty) return;
    setState(() {
      _glowReplayTokens[badgeId] = (_glowReplayTokens[badgeId] ?? 0) + 1;
    });
  }

  void _handleRetry() {
    setState(() => _pageError = null);
    widget.onRetryMetrics?.call();
    _loadFeatured();
    _loadFollowerCount();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.metrics.metricsLoadFailed) {
      return _buildMetricsErrorState();
    }

    try {
      return _buildPageContent();
    } catch (error, stackTrace) {
      debugPrint(
        '[SellerAchievementsPage] build failed: $error\n$stackTrace',
      );
      return _buildFatalErrorState(error);
    }
  }

  Widget _buildMetricsErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 12),
            const Text(
              'Başarılar yüklenemedi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mağaza verileri alınamadı. Profil bilgilerini yükleyip tekrar dene.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _handleRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFatalErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 12),
            const Text(
              'Başarılar yüklenemedi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              kDebugMode ? error.toString() : 'Beklenmeyen bir hata oluştu.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _handleRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    final badges = _resolveBadges();
    final earnedCount =
        badges.where((b) => b.status == SellerBadgeStatus.earned).length;
    final inProgressCount =
        badges.where((b) => b.status == SellerBadgeStatus.inProgress).length;
    final featuredCount = _featuredBadgeIds.length;
    final welcomeActive = SellerBadgePublicDisplay.isWelcomeSupportActive(
      _metrics,
    );

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pageError != null) ...[
            _buildInlineErrorBanner(_pageError!),
            const SizedBox(height: 12),
          ],
          _buildHero(),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final minWidth = constraints.maxWidth > 900 ? 200.0 : 160.0;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: minWidth,
                    child: SellerAchievementsSummaryCard(
                      title: 'Kazanılan Rozetler',
                      value: '$earnedCount',
                      subtitle: 'Gerçek ilerleme',
                      icon: Icons.emoji_events_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(
                    width: minWidth,
                    child: SellerAchievementsSummaryCard(
                      title: 'Devam Eden Görevler',
                      value: '$inProgressCount',
                      subtitle: 'Aktif hedefler',
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFF0EA5E9),
                    ),
                  ),
                  SizedBox(
                    width: minWidth,
                    child: SellerAchievementsSummaryCard(
                      title: 'Profilde Gösterilen',
                      value: _loadingFeatured ? '—' : '$featuredCount',
                      subtitle: 'En fazla 4 rozet',
                      icon: Icons.star_outline_rounded,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                  SizedBox(
                    width: minWidth,
                    child: const SellerAchievementsSummaryCard(
                      title: 'Bölge Sıralaması',
                      value: 'Yakında',
                      subtitle: 'Veri bekleniyor',
                      icon: Icons.map_outlined,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          SellerBrandVerificationCard(
            sellerId: widget.metrics.sellerId,
            isBrandVerified: _isBrandVerified || widget.metrics.isBrandVerified,
            application: _brandVerificationApplication,
            onChanged: _loadBrandVerification,
          ),
          const SizedBox(height: 20),
          _buildNewSellerSection(welcomeActive),
          const SizedBox(height: 20),
          _buildFeaturedSection(badges),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 4),
            child: SellerBadgeCategoryChipBar(
              selectedCategory: _selectedCategory,
              onSelected: _onCategorySelected,
            ),
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: _tasksSectionKey,
            child: _buildAllTasksSection(badges),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF991B1B),
              ),
            ),
          ),
          TextButton(onPressed: _handleRetry, child: const Text('Yenile')),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAF2)),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF8F5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Başarılarım',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Görevleri tamamla, rozet kazan ve mağaza profilinde en güçlü 4 rozetini sergile.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildNewSellerSection(bool welcomeActive) {
    final newSeller = SellerBadgeProgressResolver.resolveById(
      'new_seller',
      _metrics,
    );
    final support = SellerBadgePublicDisplay.welcomeSupportDefinition;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yeni Satıcı Alanı',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (newSeller != null)
                SellerBadgeIcon(
                  progress: newSeller,
                  animateGlow: false,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      newSeller?.status == SellerBadgeStatus.earned
                          ? 'Yeni Satıcı rozeti aktif'
                          : 'Yeni satıcı başlangıç rozeti',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      newSeller?.definition.description ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EAF2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  support.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  support.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  welcomeActive
                      ? 'Yeni satıcılar için aktif destek programı'
                      : 'Program yalnızca yeni satıcılar için geçerlidir',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: welcomeActive
                        ? const Color(0xFF059669)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedSection(List<SellerBadgeProgress> badges) {
    final earned = badges
        .where((badge) => badge.status == SellerBadgeStatus.earned)
        .toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rozet Vitrinim',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Kazandığın rozetlerden en fazla 4 tanesini profilinde göster.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          if (earned.isEmpty)
            Text(
              'Henüz vitrine ekleyebileceğin kazanılmış rozet yok.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: earned.map((badge) {
                final badgeId = badge.definition.badgeId;
                final selected = _featuredBadgeIds.contains(badgeId);
                return SellerFeaturedBadgeTile(
                  progress: badge,
                  selected: selected,
                  onTap: () => _toggleFeatured(badge),
                  animateGlow: _shouldAnimateGlow(badge),
                  glowReplayToken: _glowReplayTokenFor(badgeId),
                  onReplayGlow: () => _replayBadgeGlow(badgeId),
                );
              }).toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _buildAllTasksSection(List<SellerBadgeProgress> badges) {
    if (badges.isEmpty) {
      return _buildTasksEmptyFallback();
    }

    final grouped = <SellerBadgeCategory, List<SellerBadgeProgress>>{};
    for (final badge in badges) {
      grouped.putIfAbsent(badge.definition.category, () => []).add(badge);
    }

    final visibleCategories = SellerBadgeCategory.values
        .where((category) => (grouped[category] ?? const []).isNotEmpty)
        .where(
          (category) =>
              _selectedCategory == null || _selectedCategory == category,
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tüm Görevler',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (visibleCategories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Bu kategoride görev bulunamadı.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        for (final category in visibleCategories) ...[
          KeyedSubtree(
            key: _categoryKeys[category],
            child: Text(
              sellerBadgeCategoryLabel(category),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...grouped[category]!.map(
            (badge) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SellerBadgeTaskCard(
                progress: badge,
                animateGlow: _shouldAnimateGlow(badge),
                glowReplayToken:
                    _glowReplayTokenFor(badge.definition.badgeId),
                onNavigateToStoreProfile: widget.onNavigateToStoreProfile,
                onRetry: widget.onRetryMetrics,
                onReplayGlow: () =>
                    _replayBadgeGlow(badge.definition.badgeId),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildTasksEmptyFallback() {
    final fallbackBadges = SellerBadgeProgressResolver.resolveAll(
      const SellerBadgeStoreMetrics(),
    );
    if (fallbackBadges.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Görevler şu an yüklenemiyor.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      );
    }
    return _buildAllTasksSection(fallbackBadges);
  }
}
