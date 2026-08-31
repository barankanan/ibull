import 'package:flutter/material.dart';

import '../delivery/ihiz_delivery_status.dart';
import '../delivery/ihiz_public_tracking.dart';
import '../theme/ihiz_brand.dart';

class IhizTrackingTimeline extends StatelessWidget {
  const IhizTrackingTimeline({super.key, required this.tracking});

  final IhizPublicTracking tracking;

  @override
  Widget build(BuildContext context) {
    final steps = _steps();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: IhizBrand.line),
        boxShadow: IhizBrand.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TESLİMAT ZAMAN ÇİZELGESİ',
            style: TextStyle(
              color: IhizBrand.blue,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          if (tracking.events.isEmpty)
            Text(
              tracking.friendlyMessage,
              style: const TextStyle(
                color: IhizBrand.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final last = index == steps.length - 1;
              return _TimelineRow(step: step, isLast: last);
            }),
        ],
      ),
    );
  }

  List<_TimelineStep> _steps() {
    if (tracking.events.isNotEmpty) {
      final current = IhizDeliveryStatus.normalize(tracking.status);
      return tracking.orderedEvents.map((event) {
        final status = IhizDeliveryStatus.normalize(event.status ?? event.eventType);
        final done = _isDone(status, current);
        final active = status == current;
        return _TimelineStep(
          title: event.displayTitle,
          timeText: _formatTime(event.createdAt),
          done: done && !active,
          active: active,
        );
      }).toList(growable: false);
    }

    final current = IhizDeliveryStatus.normalize(tracking.status);
    return IhizDeliveryStatus.timelineOrder.map((status) {
      final active = status == current;
      final done = _isDone(status, current);
      return _TimelineStep(
        title: IhizDeliveryStatus.label(status),
        timeText: active
            ? 'Şu anda'
            : (done ? _formatTime(_stampFor(status)) : 'Bekleniyor'),
        done: done && !active,
        active: active,
      );
    }).toList(growable: false);
  }

  bool _isDone(String status, String current) {
    if (current == IhizDeliveryStatus.cancelled) {
      return false;
    }
    final order = IhizDeliveryStatus.timelineOrder;
    final currentIndex = order.indexOf(current);
    final statusIndex = order.indexOf(status);
    if (currentIndex < 0 || statusIndex < 0) return false;
    return statusIndex < currentIndex || current == IhizDeliveryStatus.delivered;
  }

  DateTime? _stampFor(String status) {
    switch (status) {
      case IhizDeliveryStatus.created:
        return tracking.createdAt;
      case IhizDeliveryStatus.courierPickedUp:
        return tracking.pickedUpAt;
      case IhizDeliveryStatus.delivered:
        return tracking.deliveredAt;
      default:
        return null;
    }
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    final month = months[local.month - 1];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} $month $hh:$mm';
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.title,
    required this.timeText,
    required this.done,
    required this.active,
  });

  final String title;
  final String timeText;
  final bool done;
  final bool active;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.isLast});

  final _TimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = step.done || step.active ? IhizBrand.blue : IhizBrand.inkSoft;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: step.done
                    ? IhizBrand.blue
                    : step.active
                    ? IhizBrand.blueBright
                    : Colors.white,
                border: Border.all(color: color, width: 2),
              ),
              child: step.done
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 42,
                color: step.done ? IhizBrand.blue : IhizBrand.line,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    color: IhizBrand.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (step.timeText.isNotEmpty)
                  Text(
                    step.timeText,
                    style: const TextStyle(
                      color: IhizBrand.inkSoft,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
