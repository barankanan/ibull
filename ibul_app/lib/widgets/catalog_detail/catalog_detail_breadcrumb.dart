import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/ibul_chrome.dart';

/// Product-detail breadcrumb chrome. Vehicle/other listing types pass [parts].
class CatalogDetailBreadcrumb extends StatelessWidget {
  const CatalogDetailBreadcrumb({
    super.key,
    required this.parts,
    this.leading,
  });

  final List<String> parts;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final crumbs = parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (crumbs.isEmpty && leading == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: IbulChrome.contentConstraints,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                ...crumbs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final text = entry.value;
                  final isLast = i == crumbs.length - 1;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 11,
                          color: isLast ? Colors.black54 : AppColors.primary,
                          fontWeight: isLast
                              ? FontWeight.w400
                              : FontWeight.w500,
                        ),
                      ),
                      if (!isLast)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
