import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../widgets/staggered_reveal.dart';

class InvestorTokens {
  const InvestorTokens._();

  static const Color ink = AppColors.textDark;
  static const Color muted = AppColors.textGrey;
  static const Color surface = Colors.white;
  static const Color canvas = AppColors.background;
  static const Color wash = Color(0xFFF4EDFF);
  static const Color line = Color(0xFFE6E0F0);
  static const double maxWidth = 1120;
  static const double radius = 16;

  static bool isMobile(double width) => width < 720;
  static bool isTablet(double width) => width >= 720 && width < 1024;

  static double gutter(double width) => isMobile(width) ? 16 : 32;
  static double sectionGap(double width) => isMobile(width) ? 48 : 80;
}

enum InvestorStatus { live, vision, longTerm, demo }

class InvestorStatusChip extends StatelessWidget {
  const InvestorStatusChip(this.status, {super.key});

  final InvestorStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      InvestorStatus.live => ('Canlı', const Color(0xFF1B7F5A)),
      InvestorStatus.vision => ('Vizyon', const Color(0xFF8A5A12)),
      InvestorStatus.longTerm => ('Uzun vade', AppColors.primary),
      InvestorStatus.demo => ('Örnek gösterim', const Color(0xFF6B5B95)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class InvestorSection extends StatelessWidget {
  const InvestorSection({
    super.key,
    required this.child,
    this.revealId,
    this.background,
  });

  final Widget child;
  final String? revealId;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final padded = Padding(
      padding: EdgeInsets.fromLTRB(
        InvestorTokens.gutter(width),
        InvestorTokens.sectionGap(width),
        InvestorTokens.gutter(width),
        0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: InvestorTokens.maxWidth),
          child: child,
        ),
      ),
    );
    final painted = background == null
        ? padded
        : ColoredBox(color: background!, child: padded);
    if (revealId == null) return painted;
    return StaggeredReveal(revealId: revealId!, index: 0, child: painted);
  }
}

class InvestorHeader extends StatelessWidget {
  const InvestorHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.status,
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final InvestorStatus? status;

  @override
  Widget build(BuildContext context) {
    final mobile = InvestorTokens.isMobile(MediaQuery.sizeOf(context).width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (status != null) ...[
          InvestorStatusChip(status!),
          const SizedBox(height: 12),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            style: TextStyle(
              color: InvestorTokens.ink,
              fontWeight: FontWeight.w900,
              fontSize: mobile ? 26 : 34,
              height: 1.18,
              letterSpacing: -0.4,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(
              subtitle!,
              style: TextStyle(
                color: InvestorTokens.muted,
                fontWeight: FontWeight.w600,
                fontSize: mobile ? 14.5 : 16,
                height: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class InvestorCard extends StatelessWidget {
  const InvestorCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(InvestorTokens.radius),
        border: Border.all(color: InvestorTokens.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class InvestorIconCard extends StatelessWidget {
  const InvestorIconCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.status,
  });

  final IconData icon;
  final String title;
  final String body;
  final InvestorStatus? status;

  @override
  Widget build(BuildContext context) {
    return InvestorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.softPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const Spacer(),
              if (status != null) InvestorStatusChip(status!),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: InvestorTokens.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: InvestorTokens.muted,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class InvestorPrimaryButton extends StatelessWidget {
  const InvestorPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: Size(expanded ? double.infinity : 0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: child) : child;
  }
}

class InvestorSecondaryButton extends StatelessWidget {
  const InvestorSecondaryButton({
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
  Widget build(BuildContext context) {
    final child = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.north_east_rounded, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: InvestorTokens.ink,
        side: const BorderSide(color: InvestorTokens.line, width: 1.4),
        backgroundColor: Colors.white,
        minimumSize: Size(expanded ? double.infinity : 0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: child) : child;
  }
}

class InvestorFlow extends StatelessWidget {
  const InvestorFlow({super.key, required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final mobile = InvestorTokens.isMobile(MediaQuery.sizeOf(context).width);
    if (mobile) {
      return Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _FlowNode(label: steps[i]),
            if (i != steps.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Icon(Icons.south_rounded, color: AppColors.primary),
              ),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _FlowNode(label: steps[i]),
          if (i != steps.length - 1)
            const Icon(Icons.east_rounded, color: AppColors.primary, size: 18),
        ],
      ],
    );
  }
}

class _FlowNode extends StatelessWidget {
  const _FlowNode({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.softPurple,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: InvestorTokens.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: InvestorTokens.ink,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class InvestorResponsiveGrid extends StatelessWidget {
  const InvestorResponsiveGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final medium = constraints.maxWidth >= 560;
        final columns = wide ? 3 : (medium ? 2 : 1);
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 14 * (columns - 1)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}
