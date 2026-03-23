import 'package:flutter/material.dart';

class AdminPanelStatusScaffold extends StatelessWidget {
  const AdminPanelStatusScaffold({
    super.key,
    required this.body,
    this.maxWidth = 440,
  });

  final Widget body;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: _AdminPanelStatusCard(body: body),
        ),
      ),
    );
  }
}

class AdminAccessDeniedState extends StatelessWidget {
  const AdminAccessDeniedState({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AdminPanelStatusState(
      icon: Icons.lock_outline_rounded,
      title: 'Bu modul icin erisiminiz yok',
      description:
          'Rol katalogunda bu hesaba atanmis moduller gorunur durumdadir.',
    );
  }
}

class AdminPreparingState extends StatelessWidget {
  const AdminPreparingState({super.key, required this.sectionTitle});

  final String sectionTitle;

  @override
  Widget build(BuildContext context) {
    return _AdminPanelStatusState(
      icon: Icons.construction,
      title: '$sectionTitle sayfası hazırlanıyor...',
    );
  }
}

class _AdminPanelStatusState extends StatelessWidget {
  const _AdminPanelStatusState({
    required this.icon,
    required this.title,
    this.description,
  });

  final IconData icon;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: _AdminPanelStatusCard(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminPanelStatusCard extends StatelessWidget {
  const _AdminPanelStatusCard({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(24),
      child: Padding(padding: const EdgeInsets.all(24), child: body),
    );
  }
}
