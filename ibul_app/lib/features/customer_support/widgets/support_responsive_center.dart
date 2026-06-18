import 'package:flutter/material.dart';

const double kSupportHubMaxWidth = 1100;
const double kSupportChatMaxWidth = 920;

class SupportResponsiveCenter extends StatelessWidget {
  const SupportResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 900,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
