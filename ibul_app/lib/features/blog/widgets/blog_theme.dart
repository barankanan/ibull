import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';

/// White, image-forward reading layout with the İBUL purple accent.
abstract final class BlogTheme {
  static const Color accent = AppColors.primary;
  static const Color accentSoft = Color(0xFFF3ECFF);
  static const Color ink = Color(0xFF16141F);
  static const Color body = Color(0xFF34313F);
  static const Color muted = Color(0xFF6B6878);
  static const Color line = Color(0xFFECEAF2);
  static const Color surface = Colors.white;
  static const Color placeholder = Color(0xFFF4F2F8);

  static const double readingWidth = 720;
  static const double pageWidth = 1200;
  static const double cardImageAspect = 16 / 10;
  static const double coverAspect = 16 / 9;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  static double gutter(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1100) return 40;
    if (width >= 700) return 28;
    return 18;
  }

  /// 3 columns desktop, 2 tablet, 1 mobile.
  static int gridColumns(double width) {
    if (width >= 1000) return 3;
    if (width >= 640) return 2;
    return 1;
  }

  static TextStyle titleStyle(BuildContext context) => TextStyle(
    fontSize: isWide(context) ? 42 : 30,
    height: 1.18,
    fontWeight: FontWeight.w800,
    color: ink,
    letterSpacing: -0.6,
  );

  static TextStyle subtitleStyle(BuildContext context) => TextStyle(
    fontSize: isWide(context) ? 21 : 18,
    height: 1.5,
    color: muted,
  );

  static TextStyle bodyStyle(BuildContext context) => TextStyle(
    fontSize: isWide(context) ? 18.5 : 17,
    height: 1.75,
    color: body,
  );

  static TextStyle headingStyle(BuildContext context, int level) => TextStyle(
    fontSize: level == 2
        ? (isWide(context) ? 28 : 24)
        : (isWide(context) ? 22 : 20),
    height: 1.3,
    fontWeight: FontWeight.w800,
    color: ink,
  );

  static const TextStyle metaStyle = TextStyle(
    fontSize: 14,
    color: muted,
    height: 1.4,
  );

  static const TextStyle chipStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: accent,
    letterSpacing: 0.3,
  );

  static String formatDate(DateTime? date) {
    if (date == null) return '';
    try {
      return DateFormat('d MMMM y', 'tr_TR').format(date);
    } catch (_) {
      return DateFormat('dd.MM.y').format(date);
    }
  }

  static String readingLabel(int minutes) => '$minutes dk okuma';
}

/// Network image with a neutral placeholder and HTML fallback on web so
/// cross-origin thumbnails still render.
class BlogImage extends StatelessWidget {
  const BlogImage({
    super.key,
    required this.url,
    this.semanticLabel,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final String? semanticLabel;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final value = url?.trim() ?? '';
    const placeholder = ColoredBox(
      color: BlogTheme.placeholder,
      child: Center(
        child: Icon(Icons.image_outlined, color: BlogTheme.line, size: 40),
      ),
    );
    if (value.isEmpty) return placeholder;
    return Image.network(
      value,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      semanticLabel: semanticLabel,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}
