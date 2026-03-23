import 'package:flutter/material.dart';

class InsightCard extends StatelessWidget {
  const InsightCard({
    required this.title,
    required this.description,
    required this.severity,
    this.actionLabel,
    super.key,
  });

  final String title;
  final String description;
  final String severity;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      'critical' => const Color(0xFFDC2626),
      'watch' => const Color(0xFFF59E0B),
      _ => const Color(0xFF2563EB),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.tips_and_updates_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                if ((actionLabel ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    actionLabel!,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
