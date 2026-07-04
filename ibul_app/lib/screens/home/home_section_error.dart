import 'package:flutter/material.dart';

/// Inline retry for a single deferred home section — does not crash the page.
class HomeSectionError extends StatelessWidget {
  const HomeSectionError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.grey.shade600, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
            ],
          ),
        ),
      ),
    );
  }
}
