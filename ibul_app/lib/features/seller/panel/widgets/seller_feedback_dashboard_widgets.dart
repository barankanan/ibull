import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared visual tokens for the seller feedback dashboard.
abstract final class SellerFeedbackDashboardTokens {
  static const cardRadius = 14.0;
  static const cardBorder = Color(0xFFE5E7EB);
  static const cardShadow = Color(0x08000000);
  static const pageGap = 14.0;
}

class FeedbackMetricItem {
  const FeedbackMetricItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accent;
}

class SellerFeedbackDashboardHeader extends StatelessWidget {
  const SellerFeedbackDashboardHeader({
    super.key,
    required this.activeRecordCount,
    this.onRefresh,
    this.lastUpdatedLabel,
  });

  final int activeRecordCount;
  final VoidCallback? onRefresh;
  final String? lastUpdatedLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SellerFeedbackDashboardTokens.cardRadius),
        border: Border.all(color: SellerFeedbackDashboardTokens.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: SellerFeedbackDashboardTokens.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactHeader = constraints.maxWidth < 560;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Müşteri Etkileşim Merkezi',
                style: TextStyle(
                  fontSize: compactHeader ? 18 : 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Yorumlar, değerlendirmeler, sorular ve şikayetleri tek panelden takip edin.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Colors.grey.shade600,
                ),
              ),
              if (lastUpdatedLabel != null) ...[
                const SizedBox(height: 6),
                Text(
                  lastUpdatedLabel!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_rounded, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '$activeRecordCount aktif',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              if (onRefresh != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRefresh,
                  tooltip: 'Yenile',
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF8FAFC),
                    foregroundColor: const Color(0xFF475569),
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ],
            ],
          );

          return compactHeader
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 12),
                    actions,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
        },
      ),
    );
  }
}

class FeedbackMetricCard extends StatelessWidget {
  const FeedbackMetricCard({super.key, required this.item});

  final FeedbackMetricItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SellerFeedbackDashboardTokens.cardRadius),
        border: Border.all(color: SellerFeedbackDashboardTokens.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: SellerFeedbackDashboardTokens.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, size: 15, color: item.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.3,
            ),
          ),
          if (item.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              item.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}

class FeedbackMetricGrid extends StatelessWidget {
  const FeedbackMetricGrid({super.key, required this.metrics});

  final List<FeedbackMetricItem> metrics;

  int _columnsForWidth(double width) {
    if (width >= 1100) return 4;
    if (width >= 640) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsForWidth(constraints.maxWidth);
        final spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: columns == 1 ? constraints.maxWidth : itemWidth,
                  child: FeedbackMetricCard(item: metric),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class FeedbackTrendChartCard extends StatelessWidget {
  const FeedbackTrendChartCard({
    super.key,
    required this.trend,
    required this.shortDayLabel,
  });

  final List<Map<String, dynamic>> trend;
  final String Function(int weekday) shortDayLabel;

  bool get _hasData {
    for (final item in trend) {
      final total =
          (item['reviews'] as int? ?? 0) +
          (item['questions'] as int? ?? 0) +
          (item['complaints'] as int? ?? 0);
      if (total > 0) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return _dashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: 'Geri Bildirim Grafiği',
            subtitle: 'Son 7 günlük kullanıcı etkileşim yoğunluğu',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: const [
              _LegendDot(color: Color(0xFF2563EB), label: 'Yorum'),
              _LegendDot(color: Color(0xFF0EA5E9), label: 'Soru'),
              _LegendDot(color: Color(0xFFEF4444), label: 'Şikayet'),
            ],
          ),
          const SizedBox(height: 16),
          if (!_hasData)
            const FeedbackChartEmptyState()
          else
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: trend.map((item) {
                  final reviews = item['reviews'] as int? ?? 0;
                  final questions = item['questions'] as int? ?? 0;
                  final complaints = item['complaints'] as int? ?? 0;
                  final total = reviews + questions + complaints;
                  final maxValue = trend
                      .map(
                        (e) =>
                            (e['reviews'] as int? ?? 0) +
                            (e['questions'] as int? ?? 0) +
                            (e['complaints'] as int? ?? 0),
                      )
                      .fold<int>(1, (prev, next) => math.max(prev, next));
                  final ratio = total / maxValue;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (total > 0)
                            Text(
                              '$total',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: math.max(8, 140 * ratio),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFE2E8F0),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: total == 0
                                ? null
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (complaints > 0)
                                        Expanded(
                                          flex: complaints,
                                          child: Container(
                                            width: double.infinity,
                                            color: const Color(0xFFEF4444),
                                          ),
                                        ),
                                      if (questions > 0)
                                        Expanded(
                                          flex: questions,
                                          child: Container(
                                            width: double.infinity,
                                            color: const Color(0xFF0EA5E9),
                                          ),
                                        ),
                                      if (reviews > 0)
                                        Expanded(
                                          flex: reviews,
                                          child: Container(
                                            width: double.infinity,
                                            color: const Color(0xFF2563EB),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item['label']?.toString() ??
                                shortDayLabel(
                                  (item['date'] as DateTime?)?.weekday ?? 1,
                                ),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}

class FeedbackChartEmptyState extends StatelessWidget {
  const FeedbackChartEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 36, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(
            'Bu dönemde geri bildirim yok.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Yeni yorum, soru veya şikayet geldiğinde grafik burada görünür.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class RatingDistributionCard extends StatelessWidget {
  const RatingDistributionCard({
    super.key,
    required this.starDistribution,
    required this.totalReviews,
    this.averageRating,
  });

  final Map<int, int> starDistribution;
  final int totalReviews;
  final double? averageRating;

  @override
  Widget build(BuildContext context) {
    return _dashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: 'Puan Dağılımı',
            subtitle: 'Ürün ve mağaza değerlendirmeleri',
          ),
          if (averageRating != null && averageRating! > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Text(
                  averageRating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'ortalama',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (totalReviews <= 0)
            const FeedbackRatingEmptyState()
          else
            ...List.generate(5, (index) {
              final star = 5 - index;
              final count = starDistribution[star] ?? 0;
              final ratio = count / totalReviews;
              final percent = (ratio * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '$star★',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            star >= 4
                                ? const Color(0xFFF59E0B)
                                : star == 3
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '$count · %$percent',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class FeedbackRatingEmptyState extends StatelessWidget {
  const FeedbackRatingEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.star_outline_rounded, size: 32, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(
            'Henüz puanlı değerlendirme yok.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class FeedbackActionSuggestionsCard extends StatelessWidget {
  const FeedbackActionSuggestionsCard({
    super.key,
    required this.reviewCount,
    required this.questionCount,
    required this.complaintCount,
    required this.pendingQuestions,
  });

  final int reviewCount;
  final int questionCount;
  final int complaintCount;
  final int pendingQuestions;

  @override
  Widget build(BuildContext context) {
    return _dashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: 'Aksiyon Önerileri',
            subtitle: 'Öncelikli geri bildirim aksiyonları',
          ),
          const SizedBox(height: 10),
          _ActionRow(
            icon: Icons.mark_chat_unread_rounded,
            color: const Color(0xFFF97316),
            title: pendingQuestions > 0
                ? '$pendingQuestions soru yanıt bekliyor'
                : 'Yanıt bekleyen soru yok',
            subtitle: 'Hızlı yanıt güven ve dönüşümü artırır.',
            badge: pendingQuestions > 0 ? '$pendingQuestions' : null,
          ),
          _ActionRow(
            icon: Icons.rate_review_rounded,
            color: const Color(0xFF16A34A),
            title: '$reviewCount değerlendirme görünür',
            subtitle: 'Güçlü yorumları ürün detayında öne çıkarın.',
            badge: reviewCount > 0 ? '$reviewCount' : null,
          ),
          _ActionRow(
            icon: Icons.report_problem_rounded,
            color: const Color(0xFFEF4444),
            title: complaintCount > 0
                ? '$complaintCount şikayet sinyali izleniyor'
                : 'Şikayet sinyali yok',
            subtitle: 'Düşük puanlı yorumları operasyona aktarın.',
            badge: complaintCount > 0 ? '$complaintCount' : null,
          ),
          _ActionRow(
            icon: Icons.help_outline_rounded,
            color: const Color(0xFF2563EB),
            title: '$questionCount müşteri sorusu kayıtlı',
            subtitle: 'Sık sorulanları ürün sayfasında sabitleyin.',
            badge: questionCount > 0 ? '$questionCount' : null,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class FeedbackFilterBar extends StatelessWidget {
  const FeedbackFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedTab,
    required this.onTabSelected,
    required this.selectedRatingFilter,
    required this.onRatingFilterChanged,
    required this.allCount,
    required this.reviewCount,
    required this.questionCount,
    required this.complaintCount,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String selectedTab;
  final ValueChanged<String> onTabSelected;
  final String selectedRatingFilter;
  final ValueChanged<String?> onRatingFilterChanged;
  final int allCount;
  final int reviewCount;
  final int questionCount;
  final int complaintCount;

  @override
  Widget build(BuildContext context) {
    return _dashboardCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackFilters = constraints.maxWidth < 560;
          final searchField = TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Kullanıcı, ürün, yorum veya soru ara',
              hintStyle: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: Colors.grey.shade500,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          );
          final ratingDropdown = DropdownButtonFormField<String>(
            key: ValueKey<String>(selectedRatingFilter),
            initialValue: selectedRatingFilter,
            isDense: true,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Durum',
              labelStyle: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            ),
            items: const ['Tum', '5', '4', '3', '2', '1']
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      item == 'Tum' ? 'Tüm Puanlar' : '$item★',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: onRatingFilterChanged,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stackFilters) ...[
                searchField,
                const SizedBox(height: 10),
                ratingDropdown,
              ] else
                Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 10),
                    SizedBox(width: 150, child: ratingDropdown),
                  ],
                ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FeedbackTabPill(
                      label: 'Tümü',
                      count: allCount,
                      value: 'Tum',
                      selected: selectedTab == 'Tum',
                      onTap: () => onTabSelected('Tum'),
                    ),
                    const SizedBox(width: 8),
                    FeedbackTabPill(
                      label: 'Değerlendirmeler',
                      count: reviewCount,
                      value: 'Degerlendirmeler',
                      selected: selectedTab == 'Degerlendirmeler',
                      onTap: () => onTabSelected('Degerlendirmeler'),
                    ),
                    const SizedBox(width: 8),
                    FeedbackTabPill(
                      label: 'Sorular',
                      count: questionCount,
                      value: 'Sorular',
                      selected: selectedTab == 'Sorular',
                      onTap: () => onTabSelected('Sorular'),
                    ),
                    const SizedBox(width: 8),
                    FeedbackTabPill(
                      label: 'Şikayetler',
                      count: complaintCount,
                      value: 'Sikayetler',
                      selected: selectedTab == 'Sikayetler',
                      onTap: () => onTabSelected('Sikayetler'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FeedbackTabPill extends StatelessWidget {
  const FeedbackTabPill({
    super.key,
    required this.label,
    required this.count,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

class FeedbackListEmptyState extends StatelessWidget {
  const FeedbackListEmptyState({
    super.key,
    this.filtered = false,
  });

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            filtered ? Icons.filter_alt_off_outlined : Icons.inbox_outlined,
            size: 40,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 10),
          Text(
            filtered
                ? 'Bu filtreye uygun kayıt bulunamadı'
                : 'Henüz geri bildirim yok.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            filtered
                ? 'Farklı bir filtre veya arama terimi deneyin.'
                : 'Müşteriler yorum, soru veya şikayet bıraktığında burada görünecek.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class SellerFeedbackDashboardLayout extends StatelessWidget {
  const SellerFeedbackDashboardLayout({
    super.key,
    required this.metrics,
    required this.trend,
    required this.starDistribution,
    required this.totalReviews,
    required this.averageRating,
    required this.reviewCount,
    required this.questionCount,
    required this.complaintCount,
    required this.pendingQuestions,
    required this.activeRecordCount,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedTab,
    required this.onTabSelected,
    required this.selectedRatingFilter,
    required this.onRatingFilterChanged,
    required this.allCount,
    required this.listSection,
    required this.shortDayLabel,
    this.onRefresh,
  });

  final List<FeedbackMetricItem> metrics;
  final List<Map<String, dynamic>> trend;
  final Map<int, int> starDistribution;
  final int totalReviews;
  final double averageRating;
  final int reviewCount;
  final int questionCount;
  final int complaintCount;
  final int pendingQuestions;
  final int activeRecordCount;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String selectedTab;
  final ValueChanged<String> onTabSelected;
  final String selectedRatingFilter;
  final ValueChanged<String?> onRatingFilterChanged;
  final int allCount;
  final Widget listSection;
  final String Function(int weekday) shortDayLabel;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final stackAnalytics = width < 960;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SellerFeedbackDashboardHeader(
              activeRecordCount: activeRecordCount,
              onRefresh: onRefresh,
              lastUpdatedLabel: 'Canlı panel',
            ),
            const SizedBox(height: SellerFeedbackDashboardTokens.pageGap),
            FeedbackMetricGrid(metrics: metrics),
            const SizedBox(height: SellerFeedbackDashboardTokens.pageGap),
            if (stackAnalytics) ...[
              FeedbackTrendChartCard(
                trend: trend,
                shortDayLabel: shortDayLabel,
              ),
              const SizedBox(height: SellerFeedbackDashboardTokens.pageGap),
              RatingDistributionCard(
                starDistribution: starDistribution,
                totalReviews: totalReviews,
                averageRating: averageRating > 0 ? averageRating : null,
              ),
              const SizedBox(height: SellerFeedbackDashboardTokens.pageGap),
              FeedbackActionSuggestionsCard(
                reviewCount: reviewCount,
                questionCount: questionCount,
                complaintCount: complaintCount,
                pendingQuestions: pendingQuestions,
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: FeedbackTrendChartCard(
                      trend: trend,
                      shortDayLabel: shortDayLabel,
                    ),
                  ),
                  const SizedBox(width: SellerFeedbackDashboardTokens.pageGap),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        RatingDistributionCard(
                          starDistribution: starDistribution,
                          totalReviews: totalReviews,
                          averageRating:
                              averageRating > 0 ? averageRating : null,
                        ),
                        const SizedBox(
                          height: SellerFeedbackDashboardTokens.pageGap,
                        ),
                        FeedbackActionSuggestionsCard(
                          reviewCount: reviewCount,
                          questionCount: questionCount,
                          complaintCount: complaintCount,
                          pendingQuestions: pendingQuestions,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: SellerFeedbackDashboardTokens.pageGap),
            FeedbackFilterBar(
              searchController: searchController,
              onSearchChanged: onSearchChanged,
              selectedTab: selectedTab,
              onTabSelected: onTabSelected,
              selectedRatingFilter: selectedRatingFilter,
              onRatingFilterChanged: onRatingFilterChanged,
              allCount: allCount,
              reviewCount: reviewCount,
              questionCount: questionCount,
              complaintCount: complaintCount,
            ),
            const SizedBox(height: SellerFeedbackDashboardTokens.pageGap),
            listSection,
          ],
        );
      },
    );
  }
}

Widget _dashboardCard({
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(16),
}) {
  return Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(SellerFeedbackDashboardTokens.cardRadius),
      border: Border.all(color: SellerFeedbackDashboardTokens.cardBorder),
      boxShadow: const [
        BoxShadow(
          color: SellerFeedbackDashboardTokens.cardShadow,
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

Widget _sectionTitle({required String title, String? subtitle}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Color(0xFF111827),
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    ],
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.badge,
    this.isLast = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? badge;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

List<FeedbackMetricItem> buildFeedbackMetricsFromStats(
  Map<String, dynamic> stats,
) {
  final averageRating = stats['averageRating'] as double? ?? 0;
  return [
    FeedbackMetricItem(
      title: 'Ortalama Puan',
      value: averageRating <= 0 ? '-' : averageRating.toStringAsFixed(1),
      icon: Icons.star_rounded,
      accent: const Color(0xFFF59E0B),
      subtitle: '${stats['reviewCount']} değerlendirme üzerinden',
    ),
    FeedbackMetricItem(
      title: 'Toplam Geri Bildirim',
      value: '${stats['feedbackCount']}',
      icon: Icons.chat_bubble_outline_rounded,
      accent: const Color(0xFF2563EB),
      subtitle: '${stats['thisWeekCount']} kayıt bu hafta',
    ),
    FeedbackMetricItem(
      title: 'Yanıt Bekleyen Soru',
      value: '${stats['pendingQuestions']}',
      icon: Icons.mark_chat_unread_outlined,
      accent: const Color(0xFFF97316),
      subtitle: 'Hızlı dönüş bekliyor',
    ),
    FeedbackMetricItem(
      title: 'Şikayet Riski',
      value: '${stats['complaintCount']}',
      icon: Icons.report_gmailerrorred_outlined,
      accent: const Color(0xFFEF4444),
      subtitle: '%${stats['fiveStarRatio']} memnuniyet oranı',
    ),
  ];
}
