import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../services/store_follow_service.dart';
import '../helpers/seller_badge_public_display.dart';
import '../models/seller_badge_models.dart';
import '../models/seller_brand_verification_models.dart';
import '../services/seller_badge_progress_resolver.dart';
import '../services/seller_brand_verification_service.dart';
import '../services/seller_featured_badge_repository.dart';
import '../widgets/seller_achievements_dashboard_widgets.dart';
import '../widgets/seller_badge_detail_sheet.dart';
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
    final earnedBadges = badges
        .where((b) => b.status == SellerBadgeStatus.earned)
        .toList(growable: false);
    final earnedCount = earnedBadges.length;
    final inProgressBadges = badges
        .where((b) => b.status == SellerBadgeStatus.inProgress)
        .toList(growable: false);
    final inProgressCount = inProgressBadges.length;
    final featuredCount = _featuredBadgeIds.length;
    final welcomeActive = SellerBadgePublicDisplay.isWelcomeSupportActive(
      _metrics,
    );
    final filteredTaskBadges = _filteredTaskBadges(badges);

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pageError != null) ...[
            _buildInlineErrorBanner(_pageError!),
            const SizedBox(height: AchievementDashboardTokens.pageGap),
          ],
          SellerAchievementsDashboardHeader(
            earnedCount: earnedCount,
            inProgressCount: inProgressCount,
            onRefresh: _handleRetry,
          ),
          const SizedBox(height: AchievementDashboardTokens.pageGap),
          AchievementMetricGrid(
            metrics: buildAchievementMetrics(
              earnedCount: earnedCount,
              inProgressCount: inProgressCount,
              featuredCount: featuredCount,
              loadingFeatured: _loadingFeatured,
              maxFeatured: SellerFeaturedBadgeRepository.maxProfileBadges,
            ),
          ),
          const SizedBox(height: AchievementDashboardTokens.pageGap),
          SellerBrandVerificationCard(
            sellerId: widget.metrics.sellerId,
            isBrandVerified: _isBrandVerified || widget.metrics.isBrandVerified,
            application: _brandVerificationApplication,
            onChanged: _loadBrandVerification,
          ),
          const SizedBox(height: AchievementDashboardTokens.pageGap),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackColumns = constraints.maxWidth < 960;
              final mainColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildActiveGoalsSection(inProgressBadges),
                  const SizedBox(height: AchievementDashboardTokens.pageGap),
                  SellerBadgeCategoryChipBar(
                    selectedCategory: _selectedCategory,
                    onSelected: _onCategorySelected,
                  ),
                  const SizedBox(height: 10),
                  KeyedSubtree(
                    key: _tasksSectionKey,
                    child: _buildTasksGridSection(filteredTaskBadges),
                  ),
                  const SizedBox(height: AchievementDashboardTokens.pageGap),
                  EarnedBadgesGrid(
                    badges: earnedBadges,
                    featuredBadgeIds: _featuredBadgeIds,
                    onShowDetail: (badge) => showSellerBadgeDetailSheet(
                      context: context,
                      progress: badge,
                      onNavigateToStoreProfile: widget.onNavigateToStoreProfile,
                      onRetry: widget.onRetryMetrics,
                    ),
                  ),
                ],
              );
              final sideColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BadgeShowcaseCard(
                    earnedBadges: earnedBadges,
                    featuredBadgeIds: _featuredBadgeIds,
                    onToggleFeatured: _toggleFeatured,
                    animateGlowFor: _shouldAnimateGlow,
                    glowReplayTokenFor: _glowReplayTokenFor,
                    onReplayGlow: _replayBadgeGlow,
                  ),
                  const SizedBox(height: AchievementDashboardTokens.pageGap),
                  AchievementProgressSummaryCard(
                    earnedCount: earnedCount,
                    totalCount: badges.length,
                    inProgressCount: inProgressCount,
                    featuredCount: featuredCount,
                    maxFeatured: SellerFeaturedBadgeRepository.maxProfileBadges,
                    welcomeActive: welcomeActive,
                  ),
                  const SizedBox(height: AchievementDashboardTokens.pageGap),
                  _buildNewSellerSectionCompact(welcomeActive),
                ],
              );

              if (stackColumns) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sideColumn,
                    const SizedBox(height: AchievementDashboardTokens.pageGap),
                    mainColumn,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: mainColumn),
                  const SizedBox(width: AchievementDashboardTokens.pageGap),
                  Expanded(flex: 2, child: sideColumn),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<SellerBadgeProgress> _filteredTaskBadges(
    List<SellerBadgeProgress> badges,
  ) {
    return badges
        .where((badge) {
          if (badge.status == SellerBadgeStatus.earned) return false;
          if (_selectedCategory != null &&
              badge.definition.category != _selectedCategory) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  Widget _buildActiveGoalsSection(List<SellerBadgeProgress> inProgressBadges) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aktif Görevler',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          inProgressBadges.isEmpty
              ? 'Şu an devam eden görev yok.'
              : '${inProgressBadges.length} görev devam ediyor',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),
        if (inProgressBadges.isEmpty)
          const AchievementEmptyState(
            title: 'Aktif görev yok',
            message: 'Yeni görevler ilerledikçe burada görünecek.',
            icon: Icons.flag_outlined,
          )
        else
          _buildTaskCardGrid(inProgressBadges),
      ],
    );
  }

  Widget _buildTasksGridSection(List<SellerBadgeProgress> taskBadges) {
    if (taskBadges.isEmpty) {
      return AchievementEmptyState(
        title: _selectedCategory == null
            ? 'Henüz başarı bulunmuyor'
            : 'Bu kategoride görev yok',
        message: _selectedCategory == null
            ? 'Mağazanı kurdukça rozetler ve görevler burada görünecek.'
            : 'Farklı bir kategori seçerek diğer görevlere bakabilirsin.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Görevler ve İlerleme',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 10),
        _buildTaskCardGrid(taskBadges),
      ],
    );
  }

  Widget _buildTaskCardGrid(List<SellerBadgeProgress> badges) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        const spacing = 8.0;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: badges
              .map(
                (badge) => SizedBox(
                  width: columns == 1 ? constraints.maxWidth : itemWidth,
                  child: SellerBadgeTaskCard(
                    progress: badge,
                    compact: true,
                    animateGlow: _shouldAnimateGlow(badge),
                    glowReplayToken:
                        _glowReplayTokenFor(badge.definition.badgeId),
                    onNavigateToStoreProfile: widget.onNavigateToStoreProfile,
                    onRetry: widget.onRetryMetrics,
                    onReplayGlow: () =>
                        _replayBadgeGlow(badge.definition.badgeId),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildNewSellerSectionCompact(bool welcomeActive) {
    final newSeller = SellerBadgeProgressResolver.resolveById(
      'new_seller',
      _metrics,
    );
    final support = SellerBadgePublicDisplay.welcomeSupportDefinition;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AchievementDashboardTokens.cardRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yeni Satıcı',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          if (newSeller != null)
            Row(
              children: [
                SellerBadgeIcon(progress: newSeller, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    newSeller.status == SellerBadgeStatus.earned
                        ? 'Yeni Satıcı rozeti aktif'
                        : newSeller.definition.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            support.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            welcomeActive
                ? 'Yeni satıcı destek programı aktif'
                : 'Program yalnızca yeni satıcılar için',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: welcomeActive
                  ? const Color(0xFF059669)
                  : Colors.grey.shade500,
            ),
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
}
