import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import 'mall_public_format.dart';
import 'mall_public_repository.dart';

const _navy = Color(0xFF111827);
const _muted = Color(0xFF6B7280);
const _line = Color(0xFFE5E7EB);
const _canvas = Color(0xFFF7F7F8);
const _open = Color(0xFF15803D);
const _openSoft = Color(0xFFDCFCE7);

class MallPublicSkeleton extends StatelessWidget {
  const MallPublicSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('mall-public-skeleton'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _bone(height: 34, radius: 9)),
          ],
        ]),
        const SizedBox(height: 12),
        _bone(height: 92, radius: 14),
        const SizedBox(height: 12),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _bone(width: 84, height: 34, radius: 17),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _bone(height: 64, radius: 12),
        ],
      ],
    );
  }
}

Widget _bone({double? width, double height = 16, double radius = 8}) {
  return Container(
    width: width ?? double.infinity,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFE5E7EB),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class MallPublicLogo extends StatelessWidget {
  const MallPublicLogo({super.key, required this.name, this.url, this.size = 44, this.radius = 12});

  final String name;
  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: url == null
            ? Text(
                mallInitials(name),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.28, color: AppColors.primary),
              )
            : Icon(Icons.storefront_outlined, color: AppColors.primary, size: size * 0.42),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url!.isEmpty
            ? fallback
            : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}

class MallPublicIdentityCard extends StatelessWidget {
  const MallPublicIdentityCard({super.key, required this.detail, required this.hours});

  final MallPublicDetail detail;
  final MallHoursPresentation? hours;

  @override
  Widget build(BuildContext context) {
    final place = mallPlaceLabel(detail);
    final hoursLine = hours == null ? null : mallHoursCompactLine(hours!);
    final hoursColor = hours?.isOpen == false
        ? const Color(0xFFC2410C)
        : hours?.isOpen == true
            ? _open
            : _muted;
    return Container(
      key: const ValueKey('mall-public-identity'),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Row(children: [
        MallPublicLogo(name: detail.name, url: detail.logoUrl, size: 48),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              detail.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, height: 1.15, fontWeight: FontWeight.w800, color: _navy),
            ),
            if (detail.isVerified || place.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (detail.isVerified) const _VerifiedBadge(),
                if (place.isNotEmpty)
                  Text(place, style: const TextStyle(color: _muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ]),
            ],
            if (hoursLine != null) ...[
              const SizedBox(height: 3),
              Text(hoursLine, style: TextStyle(color: hoursColor, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 3),
            Text(
              mallCountLine(detail.floors.length, detail.stores.length),
              style: const TextStyle(color: _muted, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ]),
    );
  }
}

class MallPublicSectionNav extends StatelessWidget {
  const MallPublicSectionNav({super.key, required this.items, required this.selected, required this.onSelect});

  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(children: [
          for (final item in items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _NavChip(
                  key: ValueKey('mall-public-tab-$item'),
                  label: item,
                  selected: item == selected,
                  onTap: () => onSelect(item),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class MallPublicInfoRow extends StatelessWidget {
  const MallPublicInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: _muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(value, style: const TextStyle(color: _navy, fontSize: 14, fontWeight: FontWeight.w600)),
              if (detail != null)
                Text(detail!, style: const TextStyle(fontSize: 12, color: _open, fontWeight: FontWeight.w600)),
            ]),
          ),
          if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
        ]),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: _openSoft, borderRadius: BorderRadius.circular(20)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified, size: 12, color: _open),
        SizedBox(width: 3),
        Text('Doğrulandı', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _open)),
      ]),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 34,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: selected ? AppColors.primary : _line),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _navy,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const mallPublicCanvas = _canvas;
const mallPublicNavy = _navy;
const mallPublicMuted = _muted;
const mallPublicLine = _line;
