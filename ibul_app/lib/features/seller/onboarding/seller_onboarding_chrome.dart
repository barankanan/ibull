import 'package:flutter/material.dart';

import '../../../core/constants.dart';

abstract final class SellerOnboardTokens {
  static const bg = Color(0xFFF4F6FB);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE6E8F0);
  static const card = Colors.white;
  static const radius = 18.0;
  static const maxWidth = 1120.0;
}

class SellerOnboardHero extends StatelessWidget {
  const SellerOnboardHero({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 840;
    return Container(
      key: const ValueKey('seller-onboard-hero'),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1F1648),
            AppColors.primary.withValues(alpha: 0.92),
            const Color(0xFF5B4BDB),
          ],
        ),
      ),
      padding: EdgeInsets.fromLTRB(compact ? 20 : 40, 20, compact ? 20 : 40, compact ? 28 : 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: SellerOnboardTokens.maxWidth),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(height: 8),
            if (compact)
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('İşletmenizi iBul\'da Büyütün',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
                SizedBox(height: 10),
                Text(
                  'Ürünlerinizi yayınlayın, müşterilere ulaşın, mağazanızı dijital olarak yönetin.',
                  style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 15, height: 1.45),
                ),
                SizedBox(height: 20),
                _AdvantageCard(),
              ])
            else
              const Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  flex: 7,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('İşletmenizi iBul\'da Büyütün',
                        style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1.2)),
                    SizedBox(height: 10),
                    Text(
                      'Ürünlerinizi yayınlayın, müşterilere ulaşın, mağazanızı dijital olarak yönetin.',
                      style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 15, height: 1.45),
                    ),
                  ]),
                ),
                SizedBox(width: 32),
                Expanded(flex: 5, child: _AdvantageCard()),
              ]),
          ]),
        ),
      ),
    );
  }
}

class _AdvantageCard extends StatelessWidget {
  const _AdvantageCard();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.bolt_outlined, 'Hızlı başvuru'),
      (Icons.verified_outlined, 'Güvenli doğrulama'),
      (Icons.map_outlined, 'Harita ve mağaza görünürlüğü'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Icon(item.$1, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.$2,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class SellerOnboardStepper extends StatelessWidget {
  const SellerOnboardStepper({super.key, required this.current, required this.labels});

  final int current;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('seller-onboard-stepper'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Container(
                width: 36,
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i <= current ? const Color(0xFF16A34A) : SellerOnboardTokens.line,
              ),
            _StepDot(index: i, label: labels[i], current: current),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.label, required this.current});

  final int index;
  final String label;
  final int current;

  @override
  Widget build(BuildContext context) {
    final done = index < current;
    final active = index == current;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: done
                ? const Color(0xFF16A34A)
                : active
                    ? AppColors.primary
                    : const Color(0xFFE5E7EB),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: active ? Colors.white : SellerOnboardTokens.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            color: active ? AppColors.primary : SellerOnboardTokens.muted,
          ),
        ),
      ]),
    );
  }
}

class SellerOnboardSection extends StatelessWidget {
  const SellerOnboardSection({super.key, required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        color: SellerOnboardTokens.card,
        borderRadius: BorderRadius.circular(SellerOnboardTokens.radius),
        border: Border.all(color: SellerOnboardTokens.line),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: SellerOnboardTokens.ink)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: SellerOnboardTokens.muted, height: 1.4)),
        const SizedBox(height: 22),
        child,
      ]),
    );
  }
}

class SellerOnboardSummary extends StatelessWidget {
  const SellerOnboardSummary({
    super.key,
    required this.rows,
    required this.missing,
    required this.progress,
  });

  final List<(String, String)> rows;
  final int missing;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('seller-onboard-summary'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SellerOnboardTokens.card,
        borderRadius: BorderRadius.circular(SellerOnboardTokens.radius),
        border: Border.all(color: SellerOnboardTokens.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Başvuru Özeti', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: const Color(0xFFEEF0F6),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text('%${(progress * 100).round()} tamamlandı • $missing eksik alan',
            style: const TextStyle(color: SellerOnboardTokens.muted, fontSize: 12)),
        const SizedBox(height: 16),
        for (final row in rows) ...[
          Text(row.$1, style: const TextStyle(color: SellerOnboardTokens.muted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(row.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}

class SellerOnboardEmpty extends StatelessWidget {
  const SellerOnboardEmpty({super.key, required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SellerOnboardTokens.line),
      ),
      child: Column(children: [
        Icon(icon, size: 28, color: SellerOnboardTokens.muted),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: SellerOnboardTokens.muted)),
        ],
      ]),
    );
  }
}

class SellerOnboardNav extends StatelessWidget {
  const SellerOnboardNav({
    super.key,
    required this.canBack,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    this.nextEnabled = true,
  });

  final bool canBack;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final bool nextEnabled;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Row(children: [
      if (canBack)
        Expanded(
          child: OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(minimumSize: Size(wide ? 140 : double.infinity, 48)),
            child: const Text('Geri'),
          ),
        ),
      if (canBack) const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: FilledButton(
          onPressed: nextEnabled ? onNext : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 48),
          ),
          child: Text(isLast ? 'Başvuruyu Gönder' : 'Devam Et'),
        ),
      ),
    ]);
  }
}
