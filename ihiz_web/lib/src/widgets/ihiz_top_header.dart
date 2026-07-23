import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';

/// A single navigation entry in the İHIZ marketing header.
class IhizNavItem {
  const IhizNavItem({
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onTap;

  /// Emphasized items (e.g. "Admin Girişi") render as an outlined pill.
  final bool emphasized;
}

/// Sticky marketing header: brand lockup on the left, navigation on the right.
/// Collapses to a hamburger menu on narrow screens.
class IhizTopHeader extends StatefulWidget {
  const IhizTopHeader({super.key, required this.items});

  final List<IhizNavItem> items;

  @override
  State<IhizTopHeader> createState() => _IhizTopHeaderState();
}

class _IhizTopHeaderState extends State<IhizTopHeader> {
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            border: const Border(
              bottom: BorderSide(color: IhizBrand.line),
            ),
            boxShadow: [
              BoxShadow(
                color: IhizBrand.navy.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: IhizBrand.contentMaxWidth,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 16 : 28,
                      vertical: compact ? 10 : 14,
                    ),
                    child: Row(
                      children: [
                        const IhizLogoLockup(
                          size: 26,
                          color: IhizBrand.ink,
                          onDark: false,
                        ),
                        const Spacer(),
                        if (compact)
                          IconButton(
                            onPressed: () =>
                                setState(() => _menuOpen = !_menuOpen),
                            icon: Icon(
                              _menuOpen
                                  ? Icons.close_rounded
                                  : Icons.menu_rounded,
                              color: IhizBrand.ink,
                              size: 28,
                            ),
                            tooltip: 'Menü',
                          )
                        else
                          Row(
                            children: [
                              for (final item in widget.items)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: _HeaderLink(item: item),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (compact)
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState: _menuOpen
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: _MobileMenu(
                    items: widget.items,
                    onTap: () => setState(() => _menuOpen = false),
                  ),
                  secondChild: const SizedBox(width: double.infinity),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink({required this.item});

  final IhizNavItem item;

  @override
  Widget build(BuildContext context) {
    if (item.emphasized) {
      return OutlinedButton.icon(
        onPressed: item.onTap,
        icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
        label: Text(item.label),
        style: OutlinedButton.styleFrom(
          foregroundColor: IhizBrand.blue,
          side: const BorderSide(color: IhizBrand.blue, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      );
    }
    return TextButton(
      onPressed: item.onTap,
      style: TextButton.styleFrom(
        foregroundColor: IhizBrand.ink,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
      ),
      child: Text(item.label),
    );
  }
}

class _MobileMenu extends StatelessWidget {
  const _MobileMenu({required this.items, required this.onTap});

  final List<IhizNavItem> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: item.emphasized
                    ? OutlinedButton.icon(
                        onPressed: () {
                          onTap();
                          item.onTap();
                        },
                        icon: const Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 18,
                        ),
                        label: Text(item.label),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: IhizBrand.blue,
                          side: const BorderSide(
                            color: IhizBrand.blue,
                            width: 1.4,
                          ),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            onTap();
                            item.onTap();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: IhizBrand.ink,
                            minimumSize: const Size.fromHeight(44),
                            alignment: Alignment.centerLeft,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                            ),
                          ),
                          child: Text(item.label),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
