import 'package:flutter/material.dart';

class AdminApprovalActionBar extends StatelessWidget {
  const AdminApprovalActionBar({
    this.onApprove,
    this.onReject,
    this.onStop,
    this.onReviewAgain,
    super.key,
  });

  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onStop;
  final VoidCallback? onReviewAgain;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: onApprove,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Onayla'),
        ),
        OutlinedButton.icon(
          onPressed: onReviewAgain,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Incelemeye al'),
        ),
        OutlinedButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.pause_circle_outline),
          label: const Text('Durdur'),
        ),
        OutlinedButton.icon(
          onPressed: onReject,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Reddet'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB91C1C),
          ),
        ),
      ],
    );
  }
}
