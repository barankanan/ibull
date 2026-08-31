import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';

class IhizWhatIsSection extends StatelessWidget {
  const IhizWhatIsSection({super.key});

  static const _nodes = [
    (Icons.storefront_rounded, 'Mağaza'),
    (Icons.hub_rounded, 'İhız'),
    (Icons.two_wheeler_rounded, 'Kurye'),
    (Icons.home_rounded, 'Müşteri'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final compact = !IhizBrand.useMediumGrid(w);
        final wide = IhizBrand.useWideGrid(w);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IhizSectionHeader(
              eyebrow: 'İHIZ NEDİR?',
              title: 'Teslimatı sadece taşımıyoruz. Yeniden tasarlıyoruz.',
              subtitle:
                  'İhız; mağaza, kurye ve müşteri arasında çalışan akıllı teslimat platformudur. Sipariş oluştuğu anda en uygun kuryeyi eşleştirir, rotayı yönetir ve teslimatı şeffaf hale getirir.',
            ),
            SizedBox(height: compact ? 18 : 24),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 20,
                vertical: compact ? 14 : 22,
              ),
              decoration: BoxDecoration(
                gradient: IhizBrand.softBlueGradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: IhizBrand.line),
              ),
              child: wide
                  ? _HorizontalFlow(nodes: _nodes, compact: false)
                  : compact
                      ? const _CompactTwoByTwoFlow(nodes: _nodes)
                      : _HorizontalFlow(nodes: _nodes, compact: true),
            ),
          ],
        );
      },
    );
  }
}

class _HorizontalFlow extends StatelessWidget {
  const _HorizontalFlow({required this.nodes, required this.compact});

  final List<(IconData, String)> nodes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < nodes.length; i++) ...[
          Expanded(
            child: _FlowNode(
              icon: nodes[i].$1,
              label: nodes[i].$2,
              compact: compact,
            ),
          ),
          if (i < nodes.length - 1)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: IhizBrand.blue,
                size: compact ? 18 : 22,
              ),
            ),
        ],
      ],
    );
  }
}

/// Mobile: Mağaza → İhız / Kurye → Müşteri (2x2, kısa dikey ok).
class _CompactTwoByTwoFlow extends StatelessWidget {
  const _CompactTwoByTwoFlow({required this.nodes});

  final List<(IconData, String)> nodes;

  @override
  Widget build(BuildContext context) {
    Widget row(int a, int b) {
      return Row(
        children: [
          Expanded(
            child: _FlowNode(
              icon: nodes[a].$1,
              label: nodes[a].$2,
              compact: true,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.arrow_forward_rounded,
              color: IhizBrand.blue,
              size: 18,
            ),
          ),
          Expanded(
            child: _FlowNode(
              icon: nodes[b].$1,
              label: nodes[b].$2,
              compact: true,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        row(0, 1),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Icon(
            Icons.arrow_downward_rounded,
            color: IhizBrand.blue,
            size: 18,
          ),
        ),
        row(2, 3),
      ],
    );
  }
}

class _FlowNode extends StatelessWidget {
  const _FlowNode({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final padV = compact ? 12.0 : 16.0;
    final iconBox = compact ? 36.0 : 44.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: padV),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        border: Border.all(color: IhizBrand.line),
        boxShadow: IhizBrand.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconBox,
            height: iconBox,
            decoration: BoxDecoration(
              color: IhizBrand.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: IhizBrand.blue, size: compact ? 18 : 22),
          ),
          SizedBox(height: compact ? 6 : 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 13 : 15,
            ),
          ),
        ],
      ),
    );
  }
}
