import 'package:flutter/material.dart';

import '../../app/ibul_router.dart';
import '../../app/site_info_routes.dart';
import '../../core/constants.dart';
import '../legal/legal_document.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final doc = LegalDocument.byId(LegalDocumentId.faq);
    final topics = [
      for (final paragraph in doc.paragraphs) _HelpTopic.fromParagraph(paragraph),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF111827),
        centerTitle: true,
        title: const Text(
          'Yardım',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const Text(
            'Sık sorulan sorular',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            doc.updatedLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 14),
          for (final topic in topics) ...[
            _HelpCard(topic: topic),
            const SizedBox(height: 10),
          ],
          _LinkRow(
            icon: Icons.assignment_return_outlined,
            title: 'İade ve değişim',
            onTap: () => IbulRouter.push(context, SiteInfoRoutes.returns),
          ),
          const SizedBox(height: 8),
          _LinkRow(
            icon: Icons.support_agent_outlined,
            title: 'Destek talebi aç',
            onTap: () => IbulRouter.push(context, SiteInfoRoutes.support),
          ),
        ],
      ),
    );
  }
}

class _HelpTopic {
  const _HelpTopic({required this.title, required this.body, required this.icon});

  final String title;
  final String body;
  final IconData icon;

  static _HelpTopic fromParagraph(String paragraph) {
    final split = paragraph.split('?');
    final title = split.first.trim();
    final body = split.length > 1
        ? split.sublist(1).join('?').trim()
        : paragraph.trim();
    final lowered = title.toLowerCase();
    final icon = lowered.contains('sipariş')
        ? Icons.shopping_bag_outlined
        : lowered.contains('kart') || lowered.contains('ödeme')
        ? Icons.credit_card_outlined
        : lowered.contains('iade')
        ? Icons.assignment_return_outlined
        : lowered.contains('satıcı') || lowered.contains('kurye')
        ? Icons.storefront_outlined
        : Icons.help_outline;
    return _HelpTopic(
      title: split.length > 1 ? '$title?' : title,
      body: body,
      icon: icon,
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.topic});

  final _HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E7EE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(topic.icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  topic.body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6E7EE)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}
