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
