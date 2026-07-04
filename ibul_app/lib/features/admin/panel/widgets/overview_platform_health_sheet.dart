import 'package:flutter/material.dart';

import '../../../../services/admin_service.dart';

class OverviewPlatformHealthSheet extends StatelessWidget {
  const OverviewPlatformHealthSheet({
    required this.system,
    required this.user,
    required this.store,
    required this.cargo,
    super.key,
  });

  final AdminSystemMetrics system;
  final AdminUserAnalyticsSnapshot user;
  final AdminStoreAnalyticsSnapshot store;
  final AdminCargoAnalyticsSnapshot cargo;

  static Future<void> show(
    BuildContext context, {
    required AdminSystemMetrics system,
    required AdminUserAnalyticsSnapshot user,
    required AdminStoreAnalyticsSnapshot store,
    required AdminCargoAnalyticsSnapshot cargo,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => OverviewPlatformHealthSheet(
        system: system,
        user: user,
        store: store,
        cargo: cargo,
      ),
    );
  }

  static double _ratio(int value, int total) {
    if (total <= 0) return 0;
    return (value / total).clamp(0.0, 1.0);
  }

  static double _stockSignal(AdminSystemMetrics system) {
    if (system.totalProducts <= 0) return 1;
    final penalty =
        system.outOfStockProducts + (system.lowStockProducts * 0.5);
    return (1 - (penalty / system.totalProducts)).clamp(0.0, 1.0);
  }

  List<_HealthFactor> _factors() {
    final coverage = (system.dataCoveragePercent / 100).clamp(0.0, 1.0);
    final storeSignal = _ratio(system.openStores, system.totalStores);
    final activitySignal = _ratio(user.activeUsers30d, user.totalUsers);
    final supportSignal = system.totalOrders <= 0
        ? 1.0
        : (1 - (system.openSupportTickets / system.totalOrders)).clamp(0.0, 1.0);
    final stockSignal = _stockSignal(system);
    final cargoSignal = cargo.trackingCoverage.clamp(0.0, 1.0);

    return [
      _HealthFactor(
        label: 'Veri kapsamı',
        weightLabel: '%40',
        scorePercent: coverage * 100,
        valueLabel: '%${system.dataCoveragePercent.toStringAsFixed(0)}',
        description: 'Supabase sorgu başarı oranı ve sinyal görünürlüğü.',
        isWeak: coverage < 0.85,
      ),
      _HealthFactor(
        label: 'Açık mağaza oranı',
        weightLabel: '%20',
        scorePercent: storeSignal * 100,
        valueLabel:
            '${system.openStores}/${system.totalStores} açık',
        description: 'Aktif satış yapabilen mağaza payı.',
        isWeak: storeSignal < 0.7,
      ),
      _HealthFactor(
        label: 'Aktif kullanıcı kapsaması',
        weightLabel: '%15',
        scorePercent: activitySignal * 100,
        valueLabel:
            '${user.activeUsers30d}/${user.totalUsers} aktif (30 gün)',
        description: 'Son 30 günde görünür olan kullanıcı oranı.',
        isWeak: activitySignal < 0.25,
      ),
      _HealthFactor(
        label: 'Destek backlog baskısı',
        weightLabel: '%10',
        scorePercent: supportSignal * 100,
        valueLabel: '${system.openSupportTickets} açık talep',
        description: 'Açık destek taleplerinin sipariş hacmine etkisi.',
        isWeak: system.openSupportTickets >= 15,
      ),
      _HealthFactor(
        label: 'Stok sağlığı',
        weightLabel: '%15',
        scorePercent: stockSignal * 100,
        valueLabel:
            '${system.outOfStockProducts} tükenen, ${system.lowStockProducts} düşük',
        description: 'Tükenen ve düşük stoklu ürün yükü.',
        isWeak: stockSignal < 0.75,
      ),
      _HealthFactor(
        label: 'Kargo gecikmesi',
        weightLabel: 'Operasyon',
        scorePercent: cargoSignal * 100,
        valueLabel: '${cargo.delayedShipments} geciken gönderi',
        description: '48 saati aşan gönderiler ve takip kapsaması.',
        isWeak: cargo.delayedShipments >= 10 || cargoSignal < 0.8,
      ),
      _HealthFactor(
        label: 'Onay bekleyen başvurular',
        weightLabel: 'Operasyon',
        scorePercent: system.pendingSellerApplications == 0
            ? 100
            : (100 - (system.pendingSellerApplications * 8).clamp(0, 80))
                .toDouble(),
        valueLabel: '${system.pendingSellerApplications} satıcı başvurusu',
        description: 'Bekleyen satıcı onboarding kuyruğu.',
        isWeak: system.pendingSellerApplications >= 10,
      ),
    ];
  }

  List<String> _reasons(List<_HealthFactor> factors) {
    return factors
        .where((f) => f.isWeak)
        .map((f) => '${f.label}: ${f.valueLabel}')
        .toList(growable: false);
  }

  List<String> _recommendations(List<_HealthFactor> factors) {
    final tips = <String>[];
    for (final factor in factors.where((f) => f.isWeak)) {
      switch (factor.label) {
        case 'Veri kapsamı':
          tips.add('Supabase sorgu hatalarını ve eksik tabloları kontrol edin.');
        case 'Açık mağaza oranı':
          tips.add('Kapalı mağazaları inceleyin; operasyonel destek verin.');
        case 'Aktif kullanıcı kapsaması':
          tips.add('Kullanıcı geri kazanım kampanyalarını gözden geçirin.');
        case 'Destek backlog baskısı':
          tips.add('Destek kuyruğunu önceliklendirip SLA takibi yapın.');
        case 'Stok sağlığı':
          tips.add('Tükenen ürünleri ve düşük stok uyarılarını ele alın.');
        case 'Kargo gecikmesi':
          tips.add('Geciken gönderileri kargo firmalarıyla eşleştirin.');
        case 'Onay bekleyen başvurular':
          tips.add('Satıcı başvuru onay akışını hızlandırın.');
        default:
          tips.add('${factor.label} metriğini yakından izleyin.');
      }
    }
    if (tips.isEmpty) {
      tips.add('Kritik sapma yok; mevcut operasyon ritmini koruyun.');
    }
    return tips.take(5).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final factors = _factors();
    final reasons = _reasons(factors);
    final recommendations = _recommendations(factors);
    final criticalLogs = system.logs
        .where((l) => l.level == 'critical' || l.level == 'warning')
        .take(3)
        .toList(growable: false);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                'Platform Sağlığı Detayı',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Genel skor: %${system.systemHealthPercent.round()} — '
                'ağırlıklı operasyon metriklerinin birleşimi.',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              ...factors.map(
                (factor) => _FactorTile(factor: factor),
              ),
              const SizedBox(height: 12),
              _InfoBlock(
                title: 'Skoru düşüren faktörler',
                items: reasons.isEmpty
                    ? const ['Belirgin zayıf metrik tespit edilmedi.']
                    : reasons,
              ),
              const SizedBox(height: 10),
              _InfoBlock(
                title: 'İyileştirme önerileri',
                items: recommendations,
              ),
              if (criticalLogs.isNotEmpty) ...[
                const SizedBox(height: 10),
                _InfoBlock(
                  title: 'Son operasyon alarmları',
                  items: criticalLogs
                      .map((l) => '${l.title} — ${l.subtitle}')
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HealthFactor {
  const _HealthFactor({
    required this.label,
    required this.weightLabel,
    required this.scorePercent,
    required this.valueLabel,
    required this.description,
    required this.isWeak,
  });

  final String label;
  final String weightLabel;
  final double scorePercent;
  final String valueLabel;
  final String description;
  final bool isWeak;
}

class _FactorTile extends StatelessWidget {
  const _FactorTile({required this.factor});

  final _HealthFactor factor;

  @override
  Widget build(BuildContext context) {
    final color = factor.isWeak
        ? const Color(0xFFDC2626)
        : const Color(0xFF16A34A);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  factor.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                factor.weightLabel,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                factor.valueLabel,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '%${factor.scorePercent.round()}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            factor.description,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0xFF64748B))),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
