import 'package:flutter/material.dart';

ThemeData buildSellerPanelTheme(ThemeData base) {
  final textTheme = base.textTheme;

  TextStyle withFallback(
    TextStyle? style, {
    required double fontSize,
    FontWeight? fontWeight,
    double? height,
    Color? color,
  }) {
    return (style ?? const TextStyle()).copyWith(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      color: color,
    );
  }

  const compactDensity = VisualDensity(horizontal: -1.2, vertical: -1.4);
  const compactButtonPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 7,
  );

  return base.copyWith(
    visualDensity: compactDensity,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textTheme: textTheme.copyWith(
      headlineSmall: withFallback(
        textTheme.headlineSmall,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleLarge: withFallback(
        textTheme.titleLarge,
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleMedium: withFallback(
        textTheme.titleMedium,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleSmall: withFallback(
        textTheme.titleSmall,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      bodyLarge: withFallback(
        textTheme.bodyLarge,
        fontSize: 12.75,
        height: 1.3,
      ),
      bodyMedium: withFallback(
        textTheme.bodyMedium,
        fontSize: 12.25,
        height: 1.3,
      ),
      bodySmall: withFallback(
        textTheme.bodySmall,
        fontSize: 11.5,
        height: 1.22,
      ),
      labelLarge: withFallback(
        textTheme.labelLarge,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.15,
      ),
      labelMedium: withFallback(
        textTheme.labelMedium,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        height: 1.15,
      ),
      labelSmall: withFallback(
        textTheme.labelSmall,
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        height: 1.1,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        visualDensity: compactDensity,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 34),
        padding: compactButtonPadding,
        textStyle: withFallback(
          textTheme.labelLarge,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        visualDensity: compactDensity,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 34),
        padding: compactButtonPadding,
        textStyle: withFallback(
          textTheme.labelLarge,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        visualDensity: compactDensity,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 34),
        padding: compactButtonPadding,
        textStyle: withFallback(
          textTheme.labelLarge,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        visualDensity: compactDensity,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        textStyle: withFallback(
          textTheme.labelLarge,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        visualDensity: compactDensity,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(30, 30),
        padding: const EdgeInsets.all(5),
      ),
    ),
    inputDecorationTheme: (base.inputDecorationTheme).copyWith(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: -1),
      labelPadding: const EdgeInsets.symmetric(horizontal: 1),
      labelStyle: withFallback(
        textTheme.labelMedium,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
    dataTableTheme: DataTableThemeData(
      dataRowMinHeight: 40,
      dataRowMaxHeight: 44,
      headingRowHeight: 40,
      horizontalMargin: 10,
      columnSpacing: 14,
      dividerThickness: 0.8,
      headingTextStyle: withFallback(
        textTheme.labelLarge,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF374151),
      ),
      dataTextStyle: withFallback(
        textTheme.bodyMedium,
        fontSize: 12.25,
        color: const Color(0xFF111827),
      ),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      dense: true,
      visualDensity: compactDensity,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      minLeadingWidth: 18,
      minVerticalPadding: 0,
    ),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    ),
  );
}
