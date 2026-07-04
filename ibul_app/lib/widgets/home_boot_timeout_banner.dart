import 'package:flutter/material.dart';

/// Non-blocking slow-load banner — skeleton must not stay forever.
class HomeBootTimeoutBanner extends StatelessWidget {
  const HomeBootTimeoutBanner({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: const Color(0xFFFFF8E1),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: Color(0xFFF57C00)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5D4037),
                    height: 1.3,
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7B2FBE),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Yenile'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
