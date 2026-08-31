import 'package:flutter/material.dart';

import '../../core/constants.dart';
import 'investor_widgets.dart';

class InvestorStepItem {
  const InvestorStepItem({
    required this.icon,
    required this.title,
    this.caption,
  });

  final IconData icon;
  final String title;
  final String? caption;
}

class InvestorStepStrip extends StatelessWidget {
  const InvestorStepStrip({super.key, required this.steps});

  final List<InvestorStepItem> steps;

  @override
  Widget build(BuildContext context) {
    final stack = MediaQuery.sizeOf(context).width < 900;
    if (stack) {
      return Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _StepTile(index: i + 1, item: steps[i]),
            if (i != steps.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Icon(Icons.south_rounded, color: AppColors.primary),
              ),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
              child: _StepTile(index: i + 1, item: steps[i]),
            ),
          ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.item});

  final int index;
  final InvestorStepItem item;

  @override
  Widget build(BuildContext context) {
    return InvestorCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.softPurple,
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Icon(item.icon, color: AppColors.primary, size: 26),
          const SizedBox(height: 10),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: InvestorTokens.ink,
            ),
          ),
          if (item.caption != null) ...[
            const SizedBox(height: 6),
            Text(
              item.caption!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: InvestorTokens.muted,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class InvestorFigureCard extends StatelessWidget {
  const InvestorFigureCard({
    super.key,
    required this.value,
    required this.label,
    this.note,
  });

  final String value;
  final String label;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return InvestorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 28,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: InvestorTokens.ink,
              height: 1.3,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(
              note!,
              style: const TextStyle(
                color: InvestorTokens.muted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class InvestorBarChart extends StatelessWidget {
  const InvestorBarChart({super.key, required this.rows, this.caption});

  final List<(String, double, String)> rows;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return InvestorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.$1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: InvestorTokens.ink,
                    ),
                  ),
                ),
                Text(
                  row.$3,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: row.$2,
                minHeight: 10,
                backgroundColor: AppColors.softPurple,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (caption != null)
            Text(
              caption!,
              style: const TextStyle(
                color: InvestorTokens.muted,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
        ],
      ),
    );
  }
}

class InvestorSceneBoard extends StatelessWidget {
  const InvestorSceneBoard({super.key, required this.nodes, this.title});

  final List<(IconData, String)> nodes;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return InvestorCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: InvestorTokens.ink,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              for (final node in nodes)
                SizedBox(
                  width: 118,
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.softPurple,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(node.$1, color: AppColors.primary, size: 30),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        node.$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: InvestorTokens.ink,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class InvestorPhoneFrame extends StatelessWidget {
  const InvestorPhoneFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class InvestorSplitCompare extends StatelessWidget {
  const InvestorSplitCompare({
    super.key,
    required this.leftTitle,
    required this.leftItems,
    required this.rightTitle,
    required this.rightItems,
  });

  final String leftTitle;
  final List<String> leftItems;
  final String rightTitle;
  final List<String> rightItems;

  @override
  Widget build(BuildContext context) {
    final mobile = InvestorTokens.isMobile(MediaQuery.sizeOf(context).width);
    final left = _ComparePane(
      title: leftTitle,
      items: leftItems,
      muted: true,
    );
    final right = _ComparePane(
      title: rightTitle,
      items: rightItems,
      muted: false,
    );
    if (mobile) {
      return Column(children: [left, const SizedBox(height: 12), right]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
      ],
    );
  }
}

class _ComparePane extends StatelessWidget {
  const _ComparePane({
    required this.title,
    required this.items,
    required this.muted,
  });

  final String title;
  final List<String> items;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return InvestorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: muted ? InvestorTokens.muted : AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    muted ? Icons.close_rounded : Icons.check_rounded,
                    size: 18,
                    color: muted ? InvestorTokens.muted : const Color(0xFF1B7F5A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: InvestorTokens.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
