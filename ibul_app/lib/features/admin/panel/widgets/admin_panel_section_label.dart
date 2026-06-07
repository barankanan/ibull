import 'package:flutter/material.dart';

class AdminPanelSectionLabel extends StatelessWidget {
  const AdminPanelSectionLabel({
    super.key,
    required this.label,
    required this.icon,
    this.iconColor = const Color(0xFF8B5CF6),
    this.textColor = const Color(0xFF374151),
    this.fontSize = 12,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Color textColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
