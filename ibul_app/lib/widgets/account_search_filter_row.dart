import 'package:flutter/material.dart';

import '../core/constants.dart';

/// Hesap alt sayfalarında (Beğendiklerim, Değerlendirmelerim vb.) kullanılan
/// kompakt arama + filtre satırı.
class AccountSearchFilterRow extends StatelessWidget {
  const AccountSearchFilterRow({
    super.key,
    this.onSearchChanged,
    this.hintText = 'Arama yap',
    this.filterLabel = 'Filtre',
    this.filterIcon = Icons.tune_rounded,
    this.onFilterTap,
  });

  static const double rowHeight = 40;
  static const Color cardBorder = Color(0xFFE7EAF0);
  static const Color labelColor = Color(0xFF667085);
  static const Color titleColor = Color(0xFF101828);

  final ValueChanged<String>? onSearchChanged;
  final String hintText;
  final String filterLabel;
  final IconData filterIcon;
  final VoidCallback? onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: rowHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
            ),
            alignment: Alignment.center,
            child: TextField(
              onChanged: onSearchChanged,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: titleColor,
                height: 1.2,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: hintText,
                hintStyle: TextStyle(
                  color: labelColor.withValues(alpha: 0.75),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.primary.withValues(alpha: 0.9),
                  size: 20,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: rowHeight,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onFilterTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4D9F7)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(filterIcon, color: AppColors.primary, size: 17),
                  const SizedBox(width: 6),
                  Text(
                    filterLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.primary,
                      letterSpacing: -0.1,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
