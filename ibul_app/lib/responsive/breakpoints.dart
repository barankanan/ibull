library;

/// Responsive Design Breakpoints
/// 
/// Bu dosya tüm responsive breakpoint'leri tanımlar.
/// MediaQuery.of(context).size.width ile karşılaştırarak kullanın.

class ScreenBreakpoints {
  /// Mobil cihaz maksimum genişliği
  /// Telefon ve küçük devicelar
  static const double mobile = 599;

  /// Tablet cihaz maksimum genişliği
  /// iPad ve benzer boyuttaki tabletler
  static const double tablet = 1199;

  /// Desktop minimum genişliği
  /// Dizüstü bilgisayarlar ve monitörler
  static const double desktop = 1200;

  /// Çok geniş ekranlar (4K monitörler)
  static const double ultraWide = 1920;

  /// Padding değerleri - Desktop
  static const double desktopHorizontalPadding = 40;
  static const double desktopVerticalPadding = 24;

  /// Padding değerleri - Tablet
  static const double tabletHorizontalPadding = 24;
  static const double tabletVerticalPadding = 16;

  /// Padding değerleri - Mobile
  static const double mobileHorizontalPadding = 16;
  static const double mobileVerticalPadding = 12;

  /// Grid column sayıları
  static const int desktopColumns = 4;
  static const int tabletColumns = 2;
  static const int mobileColumns = 1;

  /// Max content width (desktop'te enişin genişlik)
  static const double maxContentWidth = 1400;
}

/// Ürün grid'leri için kart-genişliği tabanlı responsive kolon hesabı.
///
/// Sabit `crossAxisCount: 2`, tablet genişliklerinde dev/amatör görünen
/// kartlar üretiyordu. Kolon sayısı kullanılabilir genişlikten türetilir ve
/// kart genişliği [minCardWidth]–[maxCardWidth] bandında tutulur.
///
/// Hedef davranış (grid padding düşülmüş kullanılabilir genişlik için):
///   <~420 → 2 kolon, ~420–700 → 2-3, ~700–950 → 3-4,
///   ~950–1250 → 4-5, 1250+ → 5-6 kolon.
class ProductGridSizing {
  ProductGridSizing._();

  /// Kart bu genişliğin altına düşmesin (içerik sıkışmasın).
  static const double minCardWidth = 180;

  /// Kart bu genişliğin üstüne çıkmasın (dev kart görünümü engellenir).
  static const double maxCardWidth = 250;

  static const double defaultSpacing = 12;
  static const int minColumns = 2;
  static const int maxColumns = 6;

  /// [availableWidth]: grid'in yatay padding'i düşülmüş genişliği.
  static int columnCountForWidth(
    double availableWidth, {
    double spacing = defaultSpacing,
  }) {
    if (!availableWidth.isFinite || availableWidth <= 0) return minColumns;
    var columns =
        ((availableWidth + spacing) / (minCardWidth + spacing)).floor();
    // Kartlar maxCardWidth'i aşacaksa kolon sayısını artır.
    final minByMaxWidth =
        ((availableWidth + spacing) / (maxCardWidth + spacing)).ceil();
    if (minByMaxWidth > columns) columns = minByMaxWidth;
    if (columns < minColumns) return minColumns;
    if (columns > maxColumns) return maxColumns;
    return columns;
  }

  /// Seçilen kolon sayısında tek kartın alacağı genişlik.
  static double cardWidthFor(
    double availableWidth, {
    double spacing = defaultSpacing,
  }) {
    if (!availableWidth.isFinite || availableWidth <= 0) return minCardWidth;
    final columns = columnCountForWidth(availableWidth, spacing: spacing);
    return (availableWidth - (columns - 1) * spacing) / columns;
  }
}

/// Screen size kategorisi
enum ScreenSize {
  mobile,
  tablet,
  desktop,
  ultraWide,
}

/// Aktif screen size'ı belirlemek için extension
extension ScreenSizeExtension on double {
  ScreenSize get screenSize {
    if (this <= ScreenBreakpoints.mobile) {
      return ScreenSize.mobile;
    } else if (this <= ScreenBreakpoints.tablet) {
      return ScreenSize.tablet;
    } else if (this <= ScreenBreakpoints.ultraWide) {
      return ScreenSize.desktop;
    } else {
      return ScreenSize.ultraWide;
    }
  }

  bool get isMobile => this <= ScreenBreakpoints.mobile;
  bool get isTablet => this > ScreenBreakpoints.mobile && this <= ScreenBreakpoints.tablet;
  bool get isDesktop => this > ScreenBreakpoints.tablet && this <= ScreenBreakpoints.ultraWide;
  bool get isUltraWide => this > ScreenBreakpoints.ultraWide;
}
