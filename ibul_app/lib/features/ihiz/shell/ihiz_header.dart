import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';

/// İHIZ marketing header — İBUL marketplace navigation kullanmaz.
class IhizHeader extends StatefulWidget {
  const IhizHeader({
    super.key,
    required this.onHome,
    required this.onHowItWorks,
    required this.onTracking,
    required this.onBusinessJoin,
    required this.onLogin,
    required this.onCourierApply,
  });

  final VoidCallback onHome;
  final VoidCallback onHowItWorks;
  final VoidCallback onTracking;
  final VoidCallback onBusinessJoin;
  final VoidCallback onLogin;
  final VoidCallback onCourierApply;

  @override
  State<IhizHeader> createState() => _IhizHeaderState();
}

class _IhizHeaderState extends State<IhizHeader> {
  Future<void> _openDrawer() async {
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = width < 420 ? width * 0.86 : 340.0;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Menüyü kapat',
      barrierColor: IhizBrand.navy.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, _) {
        return Align(
          alignment: Alignment.centerRight,
          child: _IhizSideDrawer(
            width: panelWidth,
            links: _links,
            onClose: () => Navigator.of(dialogContext).pop(),
            onLogin: () {
              Navigator.of(dialogContext).pop();
              widget.onLogin();
            },
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return SlideTransition(position: slide, child: child);
      },
    );
  }

  List<_IhizHeaderLink> get _links => [
        _IhizHeaderLink('Ana Sayfa', widget.onHome),
        _IhizHeaderLink('Nasıl Çalışır?', widget.onHowItWorks),
        _IhizHeaderLink('İşletmeler', widget.onBusinessJoin),
        _IhizHeaderLink('Teslimat Takibi', widget.onTracking),
      ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.97),
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: const Border(
            bottom: BorderSide(color: IhizBrand.line),
          ),
          boxShadow: [
            BoxShadow(
              color: IhizBrand.navy.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: IhizBrand.contentMaxWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 16 : 24,
                        vertical: compact ? 10 : 12,
                      ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: widget.onHome,
                          borderRadius: BorderRadius.circular(10),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: IhizLogoLockup(
                              size: 24,
                              color: IhizBrand.ink,
                            ),
                          ),
                        ),
                        if (compact) ...[
                          const Spacer(),
                          IconButton(
                            onPressed: _openDrawer,
                            tooltip: 'Menü',
                            icon: const Icon(
                              Icons.menu_rounded,
                              color: IhizBrand.ink,
                              size: 28,
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final link in _links)
                                  Flexible(
                                    child: TextButton(
                                      onPressed: link.onTap,
                                      style: TextButton.styleFrom(
                                        foregroundColor: IhizBrand.inkSoft,
                                        minimumSize: const Size(44, 44),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      child: Text(
                                        link.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: widget.onLogin,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: IhizBrand.navy,
                              side: const BorderSide(color: IhizBrand.line),
                              backgroundColor: Colors.white,
                              minimumSize: const Size(44, 42),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            child: const Text('Giriş Yap'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: widget.onCourierApply,
                            icon: const Icon(Icons.two_wheeler_rounded, size: 16),
                            label: const Text('Kurye Ol'),
                            style: FilledButton.styleFrom(
                              backgroundColor: IhizBrand.blue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(44, 42),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IhizHeaderLink {
  const _IhizHeaderLink(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;
}

class _IhizSideDrawer extends StatelessWidget {
  const _IhizSideDrawer({
    required this.width,
    required this.links,
    required this.onClose,
    required this.onLogin,
  });

  final double width;
  final List<_IhizHeaderLink> links;
  final VoidCallback onClose;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SizedBox(
        width: width,
        height: height,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Kapat',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 26),
                  ),
                ),
                for (final link in links)
                  TextButton(
                    onPressed: () {
                      onClose();
                      link.onTap();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: IhizBrand.ink,
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size.fromHeight(44),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                    child: Text(link.label),
                  ),
                const Divider(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Hesap',
                    style: TextStyle(
                      color: IhizBrand.inkSoft,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onLogin,
                  style: TextButton.styleFrom(
                    foregroundColor: IhizBrand.blue,
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size.fromHeight(48),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Giriş Yap'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
