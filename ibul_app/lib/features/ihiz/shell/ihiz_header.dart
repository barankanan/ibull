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
  bool _menuOpen = false;

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
            final compact = constraints.maxWidth < 1180;
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
                        if (compact) const Spacer() else const SizedBox(width: 16),
                        if (compact)
                          IconButton(
                            onPressed: () =>
                                setState(() => _menuOpen = !_menuOpen),
                            tooltip: 'Menü',
                            icon: Icon(
                              _menuOpen
                                  ? Icons.close_rounded
                                  : Icons.menu_rounded,
                              color: IhizBrand.ink,
                              size: 28,
                            ),
                          )
                        else
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final link in _links)
                                      TextButton(
                                        onPressed: link.onTap,
                                        style: TextButton.styleFrom(
                                          foregroundColor: IhizBrand.ink,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          textStyle: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        child: Text(link.label),
                                      ),
                                    const SizedBox(width: 6),
                                    OutlinedButton(
                                      onPressed: widget.onLogin,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: IhizBrand.navy,
                                        side: const BorderSide(
                                          color: IhizBrand.blue,
                                          width: 1.4,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                      child: const Text('Giriş Yap'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: widget.onCourierApply,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: IhizBrand.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                      child: const Text('Kurye Ol'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    ),
                  ),
                ),
                if (compact && _menuOpen)
                  _IhizMobileMenu(
                    links: _links,
                    onLogin: () {
                      setState(() => _menuOpen = false);
                      widget.onLogin();
                    },
                    onCourierApply: () {
                      setState(() => _menuOpen = false);
                      widget.onCourierApply();
                    },
                    onNavigate: () => setState(() => _menuOpen = false),
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

class _IhizMobileMenu extends StatelessWidget {
  const _IhizMobileMenu({
    required this.links,
    required this.onLogin,
    required this.onCourierApply,
    required this.onNavigate,
  });

  final List<_IhizHeaderLink> links;
  final VoidCallback onLogin;
  final VoidCallback onCourierApply;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final link in links)
            TextButton(
              onPressed: () {
                onNavigate();
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
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: IhizBrand.navy,
              side: const BorderSide(color: IhizBrand.blue, width: 1.4),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Giriş Yap'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onCourierApply,
            style: FilledButton.styleFrom(
              backgroundColor: IhizBrand.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Kurye Ol'),
          ),
        ],
      ),
    );
  }
}
