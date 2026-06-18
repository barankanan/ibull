import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../models/seller_badge_models.dart';
import 'seller_badge_widgets.dart';

/// Harita popup sağ üst: rozetler (max 2) + kapatma.
class MapStorePopupHeaderTrailing extends StatelessWidget {
  const MapStorePopupHeaderTrailing({
    super.key,
    required this.badges,
    required this.onClose,
    this.badgeKey,
  });

  final List<SellerBadgeProgress> badges;
  final VoidCallback onClose;
  final Key? badgeKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (badges.isNotEmpty)
          SellerBadgeMapPopupRow(
            key: badgeKey,
            badges: badges,
          ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close, color: AppColors.primary, size: 24),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          tooltip: 'Kapat',
        ),
      ],
    );
  }
}

/// Harita popup — max 2 rozet, tooltip/tap info, açılışta tek seferlik glow.
class SellerBadgeMapPopupRow extends StatefulWidget {
  const SellerBadgeMapPopupRow({
    super.key,
    required this.badges,
    this.maxVisible = 2,
  });

  final List<SellerBadgeProgress> badges;
  final int maxVisible;

  @override
  State<SellerBadgeMapPopupRow> createState() => _SellerBadgeMapPopupRowState();
}

class _SellerBadgeMapPopupRowState extends State<SellerBadgeMapPopupRow> {
  bool _glowActive = false;
  Timer? _glowTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _glowActive = true);
      _glowTimer?.cancel();
      _glowTimer = Timer(const Duration(milliseconds: 1700), () {
        if (mounted) setState(() => _glowActive = false);
      });
    });
  }

  @override
  void dispose() {
    _glowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.badges.isEmpty) return const SizedBox.shrink();
    final visible = widget.badges.take(widget.maxVisible).toList(growable: false);
    final isTouchPrimary = _isTouchPrimary(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _SellerBadgeMapPopupItem(
            progress: visible[i],
            animateGlow: _glowActive,
            isTouchPrimary: isTouchPrimary,
          ),
        ],
      ],
    );
  }

  bool _isTouchPrimary(BuildContext context) {
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.android) {
      return true;
    }
    return MediaQuery.sizeOf(context).width < 900;
  }
}

class _SellerBadgeMapPopupItem extends StatelessWidget {
  const _SellerBadgeMapPopupItem({
    required this.progress,
    required this.animateGlow,
    required this.isTouchPrimary,
  });

  final SellerBadgeProgress progress;
  final bool animateGlow;
  final bool isTouchPrimary;

  @override
  Widget build(BuildContext context) {
    final icon = SellerBadgeIcon(
      progress: progress,
      size: 36,
      animateGlow: animateGlow,
    );

    if (isTouchPrimary) {
      return GestureDetector(
        onTap: () => _showBadgeInfoSheet(context, progress),
        child: icon,
      );
    }

    return Tooltip(
      richMessage: TextSpan(
        children: _tooltipSpans(progress),
      ),
      preferBelow: false,
      verticalOffset: 12,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      textStyle: const TextStyle(fontSize: 12, height: 1.35),
      child: GestureDetector(
        onTap: () => _showBadgeInfoSheet(context, progress),
        child: icon,
      ),
    );
  }

  List<InlineSpan> _tooltipSpans(SellerBadgeProgress progress) {
    final level =
        SellerBadgeLevelStyle.forLevel(progress.definition.level).label;
    return [
      TextSpan(
        text: '${progress.definition.title}\n',
        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
      ),
      TextSpan(
        text: '${progress.definition.description}\n',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.88)),
      ),
      TextSpan(
        text: 'Seviye: $level',
        style: TextStyle(
          color: AppColors.popupLavenderStrong,
          fontWeight: FontWeight.w600,
        ),
      ),
    ];
  }

  void _showBadgeInfoSheet(BuildContext context, SellerBadgeProgress progress) {
    final level =
        SellerBadgeLevelStyle.forLevel(progress.definition.level).label;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8EAF2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SellerBadgeIcon(progress: progress, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      progress.definition.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress.definition.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Seviye: $level',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
