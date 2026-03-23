import 'package:flutter/material.dart';

class AdminOperationOptionEntry {
  const AdminOperationOptionEntry({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
}

class AdminOperationSelectorCard extends StatelessWidget {
  const AdminOperationSelectorCard({
    super.key,
    required this.selectedLabel,
    required this.isExpanded,
    required this.onToggle,
    required this.options,
  });

  final String selectedLabel;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<AdminOperationOptionEntry> options;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Genel Operasyon',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          selectedLabel,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white70,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: options
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _AdminOperationOption(entry: entry),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminOperationOption extends StatelessWidget {
  const _AdminOperationOption({required this.entry});

  final AdminOperationOptionEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: entry.isActive
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: entry.isActive
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          entry.label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: entry.isActive ? 0.95 : 0.75),
            fontSize: 13,
            fontWeight: entry.isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
