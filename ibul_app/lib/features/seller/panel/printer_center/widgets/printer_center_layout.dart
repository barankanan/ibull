import 'package:flutter/material.dart';

/// Shared visual language for the Yazıcı Merkezi tab.
abstract final class PrinterCenterColors {
  static const background = Color(0xFFF7F7FA);
  static const surface = Colors.white;
  static const border = Color(0xFFE7E5EE);
  static const accent = Color(0xFF7C3AED);
  static const title = Color(0xFF111827);
  static const body = Color(0xFF4B5563);
  static const muted = Color(0xFF6B7280);
}

const double kPrinterCenterMaxWidth = 1280;
const double kPrinterCenterGap = 16;
const double kPrinterCenterCardPadding = 20;

enum PrinterCenterTone { success, warning, error, neutral, info }

Color printerCenterToneColor(PrinterCenterTone tone) => switch (tone) {
  PrinterCenterTone.success => const Color(0xFF15803D),
  PrinterCenterTone.warning => const Color(0xFFB45309),
  PrinterCenterTone.error => const Color(0xFFB91C1C),
  PrinterCenterTone.neutral => PrinterCenterColors.muted,
  PrinterCenterTone.info => PrinterCenterColors.accent,
};

class PrinterCenterCard extends StatelessWidget {
  const PrinterCenterCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kPrinterCenterCardPadding),
      decoration: BoxDecoration(
        color: PrinterCenterColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PrinterCenterColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            PrinterCenterSectionTitle(
              title: title!,
              subtitle: subtitle,
              trailing: trailing,
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

class PrinterCenterSectionTitle extends StatelessWidget {
  const PrinterCenterSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: PrinterCenterColors.title,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12.5,
              color: PrinterCenterColors.muted,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
    if (trailing == null) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: text),
        const SizedBox(width: 12),
        trailing!,
      ],
    );
  }
}

/// Side by side on wide screens (top-aligned); stacked when narrow.
class PrinterCenterTwoColumn extends StatelessWidget {
  const PrinterCenterTwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.breakpoint = 900,
  });

  final Widget left;
  final Widget right;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: kPrinterCenterGap), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: kPrinterCenterGap),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class PrinterCenterStatusItem {
  const PrinterCenterStatusItem({
    required this.label,
    required this.value,
    required this.tone,
    this.detail,
    this.icon,
  });

  final String label;
  final String value;
  final String? detail;
  final PrinterCenterTone tone;
  final IconData? icon;
}

/// Equal-width compact status tiles: 4 / 2 / 1 per row by width.
class PrinterCenterStatusStrip extends StatelessWidget {
  const PrinterCenterStatusStrip({super.key, required this.items});

  final List<PrinterCenterStatusItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final perRow = width >= 900 ? 4 : (width >= 520 ? 2 : 1);
        const gap = 12.0;
        final tileWidth = (width - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(width: tileWidth, child: _StatusTile(item: item)),
          ],
        );
      },
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.item});

  final PrinterCenterStatusItem item;

  @override
  Widget build(BuildContext context) {
    final color = printerCenterToneColor(item.tone);
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PrinterCenterColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PrinterCenterColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: PrinterCenterColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(item.icon ?? Icons.circle, size: item.icon == null ? 9 : 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (item.detail != null && item.detail!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.detail!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: PrinterCenterColors.body,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PrinterCenterNotice extends StatelessWidget {
  const PrinterCenterNotice({
    super.key,
    required this.message,
    this.tone = PrinterCenterTone.warning,
    this.action,
  });

  final String message;
  final PrinterCenterTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = printerCenterToneColor(tone);
    final text = Text(
      message,
      style: TextStyle(fontSize: 12.5, color: color, height: 1.45),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: action == null
          ? text
          : Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [text, action!],
            ),
    );
  }
}

/// Collapsed-by-default group; content renders inline (no nested scroll).
class PrinterCenterExpandable extends StatelessWidget {
  const PrinterCenterExpandable({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PrinterCenterColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PrinterCenterColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: icon == null
              ? null
              : Icon(icon, size: 20, color: PrinterCenterColors.body),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: PrinterCenterColors.title,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: PrinterCenterColors.muted,
                  ),
                ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class PrinterCenterKeyValue extends StatelessWidget {
  const PrinterCenterKeyValue({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidth = constraints.maxWidth < 420 ? 120.0 : 200.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PrinterCenterColors.muted,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: PrinterCenterColors.title,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
