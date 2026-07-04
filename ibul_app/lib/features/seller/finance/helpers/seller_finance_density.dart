enum SellerFinanceLayoutTier { compact, medium, wide }

/// Satıcı Finans dashboard içerik alanı yoğunluğu (admin panel ile uyumlu).
class SellerFinanceDensity {
  const SellerFinanceDensity._(this.tier, this.contentWidth);

  final SellerFinanceLayoutTier tier;
  final double contentWidth;

  static SellerFinanceDensity fromWidth(double width) {
    final SellerFinanceLayoutTier tier;
    if (width < 900) {
      tier = SellerFinanceLayoutTier.compact;
    } else if (width < 1200) {
      tier = SellerFinanceLayoutTier.medium;
    } else {
      tier = SellerFinanceLayoutTier.wide;
    }
    return SellerFinanceDensity._(tier, width);
  }

  bool get isCompact => tier == SellerFinanceLayoutTier.compact;
  bool get isWide => tier == SellerFinanceLayoutTier.wide;

  double get pagePadding => isCompact ? 12 : 16;
  double get sectionGap => isCompact ? 10 : 12;
  double get cardRadius => isCompact ? 12 : 14;
  double get gridSpacing => isCompact ? 10 : 12;

  int get kpiColumns {
    if (contentWidth < 520) return 1;
    if (isCompact) return contentWidth < 680 ? 1 : 2;
    if (contentWidth < 960) return 2;
    if (contentWidth >= 1400) return 5;
    return 4;
  }

  double get kpiCardHeight => isCompact ? 108 : 120;
  double get kpiCardPadding => isCompact ? 10 : 12;
  double get kpiTitleFontSize => isCompact ? 10 : 11;
  double get kpiValueFontSize => isCompact ? 15 : 17;
  double get kpiSubtitleFontSize => 9.5;

  double get headerTitleFontSize => isCompact ? 18 : 20;
  double get headerSubtitleFontSize => isCompact ? 11 : 12;
  double get sectionTitleFontSize => isCompact ? 14 : 15;
  double get sectionSubtitleFontSize => isCompact ? 11 : 12;

  bool get dashboardSideBySide => contentWidth >= 1080;
  double get chartHeight => isCompact ? 240 : 280;
  double get sidePanelMinWidth => 320;
}
