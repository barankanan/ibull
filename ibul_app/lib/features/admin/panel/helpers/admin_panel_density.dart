import 'package:flutter/material.dart';

enum AdminPanelLayoutTier { compact, medium, wide }

/// Admin içerik alanı (sidebar sonrası) genişliğine göre kompakt/rahat layout.
class AdminPanelDensity {
  const AdminPanelDensity._(this.tier, this.contentWidth);

  final AdminPanelLayoutTier tier;
  final double contentWidth;

  static AdminPanelDensity fromWidth(double width) {
    final AdminPanelLayoutTier tier;
    if (width < 900) {
      tier = AdminPanelLayoutTier.compact;
    } else if (width < 1200) {
      tier = AdminPanelLayoutTier.medium;
    } else {
      tier = AdminPanelLayoutTier.wide;
    }
    return AdminPanelDensity._(tier, width);
  }

  bool get isCompact => tier == AdminPanelLayoutTier.compact;
  bool get isMedium => tier == AdminPanelLayoutTier.medium;
  bool get isWide => tier == AdminPanelLayoutTier.wide;

  double get pagePadding => isCompact ? 12 : 16;
  double get sectionGap => isCompact ? 10 : 14;
  double get blockGap => isCompact ? 12 : 16;

  EdgeInsets get heroPadding => EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 18,
        vertical: isCompact ? 12 : (isWide ? 16 : 14),
      );

  double get heroBorderRadius => isCompact ? 12 : 14;
  double get heroTitleFontSize =>
      isCompact ? 20 : (isMedium ? 22 : 26);
  double get heroSubtitleFontSize => isCompact ? 11 : 12;
  int get heroSubtitleMaxLines => isCompact ? 1 : 2;

  /// Hero metin + gauge yan yana (dar içerik alanında dikey şişmeyi önler).
  bool get heroSideBySide => contentWidth >= 480;

  double get gaugeSize => isCompact ? 52 : (isWide ? 72 : 64);
  double get gaugeStroke => isCompact ? 5 : 7;
  double get gaugeValueFontSize => isCompact ? 16 : 20;

  /// KPI / operasyon nabzı grid kolon sayısı.
  int get gridColumns {
    if (isCompact) return contentWidth < 520 ? 1 : 2;
    if (isWide) return 4;
    return 2;
  }

  /// Operasyon Nabzı: dar=1, orta=2, geniş=4.
  int get signalGridColumns {
    if (isCompact) return 1;
    if (isWide) return 4;
    return 2;
  }

  double get signalCardPadding => isCompact ? 10 : 12;

  int get kpiColumns => gridColumns;

  double get kpiMinHeight => isCompact ? 64 : 72;
  double get kpiMaxHeight => isCompact ? 76 : 84;
  double get kpiCardPadding => isCompact ? 8 : 10;
  double get kpiIconSize => isCompact ? 14 : 16;
  double get kpiIconPadding => isCompact ? 6 : 7;
  double get kpiTitleFontSize => isCompact ? 10 : 11;
  double get kpiValueFontSize => isCompact ? 15 : 17;
  double get kpiSubtitleFontSize => 9;
  double get cardPadding => isCompact ? 12 : 16;
  double get gridSpacing => isCompact ? 8 : 10;

  double get scrollPanelMaxHeight => isCompact ? 300 : 360;

  /// İki kolonlu split section (Veri Merkezi vb.)
  bool get splitSectionSideBySide => contentWidth >= 1080;

  double get tabButtonPaddingH => isCompact ? 10 : 12;
  double get tabButtonPaddingV => isCompact ? 6 : 8;
  double get tabButtonIconSize => isCompact ? 14 : 15;
  double get tabButtonFontSize => isCompact ? 11 : 12;
  double get tabButtonRadius => isCompact ? 10 : 12;
  double get headerTitleFontSize => isCompact ? 18 : 20;
  double get dataHeroIconBox => isCompact ? 40 : 44;
  double get dataHeroIconSize => isCompact ? 20 : 22;
  double get dataHeroTitleFontSize => isCompact ? 17 : 19;
  double get surfaceCardPadding => isCompact ? 12 : 14;
  double get surfaceCardRadius => isCompact ? 12 : 14;

  // —— Mağaza Yönetimi sayfası ——
  EdgeInsets get storeHeroPadding => EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 14,
        vertical: isCompact ? 8 : (isWide ? 11 : 10),
      );

  double get storeHeroTitleFontSize => isCompact ? 17 : (isMedium ? 19 : 21);
  int get storeHeroSubtitleMaxLines => isCompact ? 1 : 2;
  double get storeHeroMetricWidth => isCompact ? 92.0 : 106.0;
  double get storeHeroMetricPaddingV => isCompact ? 6.0 : 8.0;
  double get storeHeroMetricIconBox => isCompact ? 24.0 : 26.0;
  double get storeHeroMetricValueFontSize => isCompact ? 14.0 : 15.0;
  double get storeHeroSignalPillPaddingH => isCompact ? 7.0 : 8.0;
  double get storeHeroSignalPillPaddingV => isCompact ? 4.0 : 5.0;
  double get storeHeroSignalPillFontSize => isCompact ? 9.5 : 10.0;
  double get storeHeroSignalPillIconSize => isCompact ? 12.0 : 13.0;
  double get storeHeroActionPaddingH => isCompact ? 9.0 : 10.0;
  double get storeHeroActionPaddingV => isCompact ? 6.0 : 7.0;
  double get storeHeroActionIconSize => isCompact ? 14.0 : 15.0;

  double get storeTabStripPadding => isCompact ? 4.0 : 6.0;
  double get storeTabHeight => isCompact ? 34.0 : 38.0;
  double get storeTabIconSize => isCompact ? 14.0 : 15.0;
  double get storeTabFontSize => isCompact ? 11.0 : 12.0;
  double get storeTabPaddingH => isCompact ? 10.0 : 12.0;

  double get storeSectionPadding => isCompact ? 14.0 : 18.0;
  double get storeSectionTitleFontSize => isCompact ? 17.0 : 18.0;
  double get storeSectionSubtitleFontSize => isCompact ? 12.0 : 13.0;
  double get storeListSeparator => isCompact ? 10.0 : 12.0;
  double get storeCardPadding => isCompact ? 12.0 : 14.0;
  double get storeCardBorderRadius => isCompact ? 16.0 : 18.0;
  double get storeCardIconBox => isCompact ? 40.0 : 44.0;
  double get storeCardIconSize => isCompact ? 20.0 : 22.0;
  double get storeCardTitleFontSize => isCompact ? 15.0 : 16.0;
  double get storeCardGap => isCompact ? 10.0 : 12.0;

  double get storeMetaChipPaddingH => isCompact ? 8.0 : 9.0;
  double get storeMetaChipPaddingV => isCompact ? 4.0 : 5.0;
  double get storeMetaChipFontSize => isCompact ? 11.0 : 12.0;
  double get storeMetaChipIconSize => isCompact ? 13.0 : 14.0;

  double get storeStatusChipPaddingH => isCompact ? 8.0 : 9.0;
  double get storeStatusChipPaddingV => isCompact ? 4.0 : 5.0;
  double get storeStatusChipFontSize => isCompact ? 10.0 : 11.0;

  double get storeActionPaddingH => isCompact ? 10.0 : 12.0;
  double get storeActionPaddingV => isCompact ? 8.0 : 9.0;
  double get storeActionIconSize => isCompact ? 14.0 : 15.0;
  double get storeActionRadius => isCompact ? 10.0 : 12.0;

  double get storeLocationInfoPadding => isCompact ? 10.0 : 12.0;
  double get storeLocationInfoIconBox => isCompact ? 28.0 : 30.0;
  double get storeLocationInfoIconSize => isCompact ? 15.0 : 16.0;
  double get storeLocationInfoTitleFontSize => isCompact ? 11.0 : 12.0;
  double get storeLocationInfoValueFontSize => isCompact ? 13.0 : 14.0;

  /// Kart içi info + aksiyon yan yana eşiği.
  bool get storeCardSideBySide => contentWidth >= 860;

  // —— Finans sayfası ——
  double get financeHeaderTitleFontSize => isCompact ? 17 : 19;
  double get financeHeaderSubtitleFontSize => isCompact ? 11 : 12;
  int get financeHeaderSubtitleMaxLines => isCompact ? 1 : 2;

  double get financeChipPaddingH => isCompact ? 8 : 10;
  double get financeChipPaddingV => isCompact ? 5 : 6;
  double get financeChipFontSize => isCompact ? 11 : 12;
  double get financeChipRadius => isCompact ? 8 : 10;

  double get financeSegmentPadding => isCompact ? 3 : 4;
  double get financeSegmentButtonPaddingH => isCompact ? 8 : 10;
  double get financeSegmentButtonPaddingV => isCompact ? 5 : 6;
  double get financeSegmentFontSize => isCompact ? 11 : 12;
  double get financeSegmentIconSize => isCompact ? 13 : 14;

  /// Finans KPI grid: dar=1, orta=2–3, geniş=4–5.
  int get financeKpiColumns {
    if (contentWidth < 520) return 1;
    if (isCompact) return contentWidth < 680 ? 1 : 2;
    if (isMedium) return contentWidth >= 960 ? 3 : 2;
    if (contentWidth >= 1400) return 5;
    return 4;
  }

  double get financeKpiMinHeight => isCompact ? 80 : 88;
  double get financeKpiMaxHeight => isCompact ? 96 : 105;
  double get financeKpiCardPadding => isCompact ? 8 : 10;
  double get financeKpiIconSize => isCompact ? 13 : 14;
  double get financeKpiIconPadding => isCompact ? 5 : 6;
  double get financeKpiTitleFontSize => isCompact ? 10 : 11;
  double get financeKpiValueFontSize => isCompact ? 14 : 16;
  double get financeKpiSubtitleFontSize => 9;
  double get financeKpiTrendFontSize => isCompact ? 9 : 10;

  double get financeSummaryBandPadding => isCompact ? 10 : 12;
  double get financeSummaryBandRadius => isCompact ? 10 : 12;
  double get financeSectionPadding => isCompact ? 12 : 14;
  double get financeSectionRadius => isCompact ? 12 : 14;
  double get financeSectionTitleFontSize => isCompact ? 14 : 15;
  double get financeSectionSubtitleFontSize => isCompact ? 11 : 12;
  double get financeChartHeight => isCompact ? 180 : 220;
}
