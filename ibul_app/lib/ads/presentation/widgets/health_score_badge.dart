git status --shortasdasimport 'package:flutter/material.dart';

class HealthScoreBadge extends StatelessWidget {
  const HealthScoreBadge({
    required this.score,
    this.compact = false,
    super.key,
  });

  final int score;
  final bool compact;

  String get _label {
    if (score >= 85) return 'Cok iyi';
    if (score >= 70) return 'Iyi';
    if (score >= 55) return 'Gelistirilmeli';
    return 'Zayif';
  }

  Color get _color {
    if (score >= 85) return const Color(0xFF16A34A);
    if (score >= 70) return const Color(0xFF2563EB);
    if (score >= 55) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_rounded, size: compact ? 14 : 16, color: _color),
          const SizedBox(width: 6),
          Text(
            '$score • $_label',
            style: TextStyle(
              color: _color,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
