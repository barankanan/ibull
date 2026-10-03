import 'package:flutter/material.dart';

import '../../../core/constants.dart';

class MallStepBar extends StatelessWidget {
  const MallStepBar({
    super.key,
    required this.labels,
    required this.index,
    this.errorIndex,
  });

  final List<String> labels;
  final int index;
  final int? errorIndex;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          Chip(
            label: Text('${i + 1}. ${labels[i]}'),
            backgroundColor: i == errorIndex
                ? const Color(0xFFFEE2E2)
                : i == index
                    ? AppColors.softPurple
                    : AppColors.surfaceMuted,
            side: i == errorIndex
                ? const BorderSide(color: AppColors.danger)
                : null,
          ),
      ],
    );
  }
}

class MallNoteCard extends StatelessWidget {
  const MallNoteCard({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}
