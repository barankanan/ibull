import 'package:flutter/material.dart';

import '../../../../core/constants.dart';

/// Single design system for the AVM panel: 1400 max width, 20px radius,
/// subtle borders, very light shadow, purple accent, 24/32 spacing.
class MallTokens {
  const MallTokens._();

  static const pageBackground = Color(0xFFF6F5FA);
  static const border = Color(0xFFE8E6EF);
  static const muted = Color(0xFF6B7280);
  static const soft = Color(0xFFF3EEFF);
  static const radius = 20.0;
  static const maxWidth = 1400.0;
  static const shadow = [
    BoxShadow(color: Color(0x0A1F1235), blurRadius: 16, offset: Offset(0, 4)),
  ];
}

enum MallTone { primary, success, warning, danger, neutral }

Color _toneColor(MallTone tone) => switch (tone) {
      MallTone.primary => AppColors.primary,
      MallTone.success => const Color(0xFF15803D),
      MallTone.warning => const Color(0xFFB45309),
      MallTone.danger => AppColors.danger,
      MallTone.neutral => MallTokens.muted,
    };

class MallPage extends StatelessWidget {
  const MallPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MallTokens.maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 24),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MallPageTitle extends StatelessWidget {
  const MallPageTitle({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: const TextStyle(color: MallTokens.muted)),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    );
  }
}

class MallCard extends StatelessWidget {
  const MallCard({super.key, required this.child, this.padding = const EdgeInsets.all(24), this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(MallTokens.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(MallTokens.radius),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MallTokens.radius),
            border: Border.all(color: MallTokens.border),
            boxShadow: MallTokens.shadow,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class MallCardTitle extends StatelessWidget {
  const MallCardTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class MallKpiCard extends StatelessWidget {
  const MallKpiCard({super.key, required this.label, required this.value, required this.icon, this.tone = MallTone.primary});

  final String label;
  final String value;
  final IconData icon;
  final MallTone tone;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(tone);
    return MallCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.1)),
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: MallTokens.muted, fontSize: 13, height: 1.2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive grid: [minTileWidth] decides the column count (1 on phones).
class MallGrid extends StatelessWidget {
  const MallGrid({
    super.key,
    required this.children,
    this.minTileWidth = 220,
    this.spacing = 16,
    this.maxColumns = 6,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = (constraints.maxWidth / minTileWidth).floor().clamp(1, maxColumns);
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    });
  }
}

class MallBadge extends StatelessWidget {
  const MallBadge(this.label, {super.key, this.tone = MallTone.neutral, this.icon, this.dense = false});

  final String label;
  final MallTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(tone);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 10, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: dense ? 12 : 14, color: color), const SizedBox(width: 4)],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: dense ? 11 : 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class MallEmptyState extends StatelessWidget {
  const MallEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return MallCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: MallTokens.soft, borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: MallTokens.muted)),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            MallPrimaryButton(label: actionLabel!, icon: Icons.add, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

class MallPrimaryButton extends StatelessWidget {
  const MallPrimaryButton({super.key, required this.label, this.icon, this.onPressed});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    if (icon == null) return FilledButton(onPressed: onPressed, style: style, child: Text(label));
    return FilledButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 18), label: Text(label));
  }
}

class MallSegmented extends StatelessWidget {
  const MallSegmented({super.key, required this.items, required this.selected, required this.onChanged});

  final Map<String, String> items;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in items.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: entry.key == selected,
            onSelected: (_) => onChanged(entry.key),
            selectedColor: MallTokens.soft,
            labelStyle: TextStyle(
              color: entry.key == selected ? AppColors.primary : AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
            side: const BorderSide(color: MallTokens.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            showCheckmark: false,
          ),
      ],
    );
  }
}

/// Dialog frame: 520-880 wide, title, scrollable body, actions.
class MallFormDialog extends StatelessWidget {
  const MallFormDialog({super.key, required this.title, required this.child, required this.actions, this.width = 560});

  final String title;
  final Widget child;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MallTokens.radius)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width.clamp(520, 880)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Flexible(child: SingleChildScrollView(child: child)),
              const SizedBox(height: 20),
              Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration mallInput(String label, {String? hint, String? error}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: error,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: MallTokens.border),
    ),
  );
}

class MallInlineError extends StatelessWidget {
  const MallInlineError(this.message, {super.key, this.onClose});

  final String message;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF991B1B)))),
          if (onClose != null)
            IconButton(onPressed: onClose, icon: const Icon(Icons.close, size: 18), tooltip: 'Kapat'),
        ],
      ),
    );
  }
}

/// Section-level load failure: the real error code stays in the debug log.
class MallLoadError extends StatelessWidget {
  const MallLoadError(this.message, {super.key, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MallInlineError(message),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
      ],
    );
  }
}

void showMallSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
}

Widget mallLogo(String? url, {double size = 44}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.28),
    child: Container(
      width: size,
      height: size,
      color: MallTokens.soft,
      child: url == null
          ? Icon(Icons.storefront_outlined, color: AppColors.primary, size: size * 0.5)
          : Image.network(url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.storefront_outlined, color: AppColors.primary, size: size * 0.5)),
    ),
  );
}
