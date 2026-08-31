import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';

class IhizSectionPadding extends StatelessWidget {
  const IhizSectionPadding({
    super.key,
    required this.child,
    this.top,
    this.bottom,
  });

  final Widget child;
  final double? top;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = IhizBrand.pageGutter(width);
    final gap = IhizBrand.sectionGap(width);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        gutter,
        top ?? gap,
        gutter,
        bottom ?? 0,
      ),
      child: child,
    );
  }
}

class IhizSectionHeader extends StatelessWidget {
  const IhizSectionHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.center = false,
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = IhizBrand.isMobile(width);
    final align = center ? TextAlign.center : TextAlign.start;
    final cross = center ? CrossAxisAlignment.center : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: cross,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            textAlign: align,
            style: const TextStyle(
              color: IhizBrand.blue,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          title,
          textAlign: align,
          style: TextStyle(
            color: IhizBrand.ink,
            fontWeight: FontWeight.w900,
            fontSize: mobile ? 28 : 36,
            height: 1.15,
            letterSpacing: -0.4,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              subtitle!,
              textAlign: align,
              style: TextStyle(
                color: IhizBrand.inkSoft,
                fontWeight: FontWeight.w600,
                fontSize: mobile ? 15 : 16.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class IhizPrimaryButton extends StatefulWidget {
  const IhizPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  State<IhizPrimaryButton> createState() => _IhizPrimaryButtonState();
}

class _IhizPrimaryButtonState extends State<IhizPrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      transform: Matrix4.translationValues(0, _hover ? -1.5 : 0, 0),
      child: ElevatedButton(
        onPressed: widget.onPressed,
        onHover: (v) => setState(() => _hover = v),
        style: ElevatedButton.styleFrom(
          backgroundColor: IhizBrand.blue,
          foregroundColor: Colors.white,
          elevation: _hover ? 8 : 2,
          shadowColor: IhizBrand.blue.withValues(alpha: 0.35),
          minimumSize: Size(widget.expanded ? double.infinity : 0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        child: Row(
          mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
    return widget.expanded
        ? SizedBox(width: double.infinity, child: child)
        : child;
  }
}

class IhizSecondaryButton extends StatelessWidget {
  const IhizSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
    this.onDark = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool expanded;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : IhizBrand.ink;
    final border =
        onDark ? Colors.white.withValues(alpha: 0.55) : IhizBrand.line;
    final child = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: border, width: 1.5),
        backgroundColor:
            onDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        minimumSize: Size(expanded ? double.infinity : 0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: child) : child;
  }
}

class IhizFeatureCard extends StatefulWidget {
  const IhizFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.accent = IhizBrand.blue,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final bool compact;

  @override
  State<IhizFeatureCard> createState() => _IhizFeatureCardState();
}

class _IhizFeatureCardState extends State<IhizFeatureCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final pad = widget.compact ? 16.0 : 20.0;
    final iconSize = widget.compact ? 40.0 : 46.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(widget.compact ? 16 : 20),
          border: Border.all(color: IhizBrand.line),
          boxShadow: [
            BoxShadow(
              color: IhizBrand.navy.withValues(alpha: _hover ? 0.10 : 0.05),
              blurRadius: _hover ? 28 : 18,
              offset: Offset(0, _hover ? 14 : 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.icon,
                color: widget.accent,
                size: widget.compact ? 20 : 22,
              ),
            ),
            SizedBox(height: widget.compact ? 12 : 14),
            Text(
              widget.title,
              style: TextStyle(
                color: IhizBrand.ink,
                fontWeight: FontWeight.w900,
                fontSize: widget.compact ? 16 : 17.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.body,
              style: TextStyle(
                color: IhizBrand.inkSoft,
                fontWeight: FontWeight.w600,
                fontSize: widget.compact ? 13.5 : 14.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive feature/card grid — desktop 3 col, tablet 2, mobile 1.
class IhizResponsiveCardGrid extends StatelessWidget {
  const IhizResponsiveCardGrid({
    super.key,
    required this.children,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = IhizBrand.useWideGrid(w)
            ? (children.length >= 3 ? 3 : children.length)
            : (IhizBrand.useMediumGrid(w) ? 2 : 1);

        if (cols == 1) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          if (i > 0) rows.add(SizedBox(height: spacing));
          final slice = children.sublist(
            i,
            i + cols > children.length ? children.length : i + cols,
          );
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) SizedBox(width: spacing),
                    Expanded(
                      child: j < slice.length ? slice[j] : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class IhizBulletRow extends StatelessWidget {
  const IhizBulletRow({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: IhizBrand.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 15,
              color: IhizBrand.blue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: IhizBrand.ink,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
