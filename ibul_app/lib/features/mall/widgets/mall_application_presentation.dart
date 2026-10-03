import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants.dart';

/// Logo ve kapak çerçevesi. Önce yerel bayt, sonra kayıtlı URL.
class MallImageFrame extends StatelessWidget {
  const MallImageFrame({
    super.key,
    required this.bytes,
    required this.url,
    required this.aspectRatio,
    required this.placeholder,
    required this.logTag,
  });

  final Uint8List? bytes;
  final String? url;
  final double aspectRatio;
  final Widget placeholder;
  final String logTag;

  @override
  Widget build(BuildContext context) {
    final memory = bytes;
    if (memory != null && memory.isNotEmpty) {
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: Image.memory(memory, fit: BoxFit.cover, gaplessPlayback: true),
      );
    }
    final network = url?.trim() ?? '';
    if (network.isNotEmpty) {
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: Image.network(
          network,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) {
            debugPrint('[MALL][$logTag] URL:$network error:$error');
            return placeholder;
          },
        ),
      );
    }
    return AspectRatio(aspectRatio: aspectRatio, child: placeholder);
  }
}

class MallApplicationStepper extends StatelessWidget {
  const MallApplicationStepper({
    super.key,
    required this.labels,
    required this.index,
    this.errorIndex,
    this.incompleteSteps = const {},
    this.onSelect,
  });

  final List<String> labels;
  final int index;
  final int? errorIndex;

  /// Steps the submit validator still reports; these never show ✓.
  final Set<int> incompleteSteps;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 1100;
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (index + 1) / labels.length,
              minHeight: 6,
              color: AppColors.primary,
              backgroundColor: AppColors.border,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${index + 1} / ${labels.length}  ${labels[index]}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          _StepChip(
            number: i + 1,
            label: labels[i],
            active: i == index,
            done: i < index && !incompleteSteps.contains(i),
            error: i == errorIndex || (i < index && incompleteSteps.contains(i)),
            onTap: onSelect == null ? null : () => onSelect!(i),
          ),
          if (i < labels.length - 1)
            const SizedBox(width: 18, child: Divider()),
        ],
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.number,
    required this.label,
    required this.active,
    required this.done,
    required this.error,
    this.onTap,
  });

  final int number;
  final String label;
  final bool active;
  final bool done;
  final bool error;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = error
        ? AppColors.danger
        : active || done
            ? AppColors.primary
            : AppColors.onSurfaceMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: active ? AppColors.primary : color.withValues(alpha: 0.12),
              child: Text(
                done && !error ? '✓' : '$number',
                style: TextStyle(
                  fontSize: 11,
                  color: active ? Colors.white : color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MallApplicationSummary extends StatelessWidget {
  const MallApplicationSummary({
    super.key,
    required this.name,
    required this.city,
    required this.district,
    this.address = '',
    required this.floorLabel,
    required this.logoBytes,
    required this.coverBytes,
    required this.logoUrl,
    required this.coverUrl,
    required this.ready,
    this.missing = const [],
  });

  final List<String> missing;
  final String name;
  final String city;
  final String district;
  final String address;
  final String? floorLabel;
  final Uint8List? logoBytes;
  final Uint8List? coverBytes;
  final String? logoUrl;
  final String? coverUrl;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final place = [district.trim(), city.trim()].where((part) => part.isNotEmpty).join(' / ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Başvuru Özeti', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: AppColors.surfaceMuted,
              child: MallImageFrame(
                bytes: coverBytes,
                url: coverUrl,
                aspectRatio: 16 / 6,
                logTag: 'COVER_PREVIEW',
                placeholder: const Center(child: Icon(Icons.panorama_outlined)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: ColoredBox(
                    color: AppColors.surfaceMuted,
                    child: MallImageFrame(
                      bytes: logoBytes,
                      url: logoUrl,
                      aspectRatio: 1,
                      logTag: 'LOGO_PREVIEW',
                      placeholder: const Icon(Icons.apartment, color: AppColors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.trim().isEmpty ? 'AVM adı' : name.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (place.isNotEmpty) Text(place),
                    if (address.trim().isNotEmpty)
                      Text(
                        address.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (floorLabel != null) Text(floorLabel!),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ready ? 'Gönderilmeye hazır' : 'Eksik bilgiler:',
            style: TextStyle(
              color: ready ? const Color(0xFF15803D) : AppColors.onSurfaceMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!ready)
            for (final field in missing)
              Text('• $field', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
