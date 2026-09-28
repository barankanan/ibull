import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants.dart';
import '../domain/coupon_models.dart';

class RewardWheelAdminHeader extends StatelessWidget {
  const RewardWheelAdminHeader({
    required this.active,
    required this.onActiveChanged,
    super.key,
  });

  final bool active;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hediye Çarkı',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text(
                'Kullanıcılara gösterilecek ödülleri, kuponları ve kazanma oranlarını yönetin.',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
            ],
          ),
        ),
        Column(
          children: [
            Switch.adaptive(
              value: active,
              activeThumbColor: AppColors.primary,
              onChanged: onActiveChanged,
            ),
            Text(
              active ? 'Çark Aktif' : 'Çark Pasif',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

class RewardWheelStatCards extends StatelessWidget {
  const RewardWheelStatCards({required this.stats, super.key});

  final RewardWheelAdminStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Aktif Ödüller', stats.activeRewards, const Color(0xFF7A2FF4)),
      ('Bekleyen Satıcı Teklifleri', stats.pendingSellerOffers, const Color(0xFFD97706)),
      ('Bugünkü Çevirme', stats.todaySpins, const Color(0xFF0EA5E9)),
      ('Bugün Kazanılan Kupon', stats.todayWins, const Color(0xFF16A34A)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 1100
            ? (width - 36) / 4
            : width >= 720
            ? (width - 12) / 2
            : width;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              Container(
                width: cardWidth,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEDE9FE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$1,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.$2}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: item.$3,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class RewardWheelProbabilityBar extends StatelessWidget {
  const RewardWheelProbabilityBar({
    required this.totalPercent,
    super.key,
  });

  final int totalPercent;

  @override
  Widget build(BuildContext context) {
    final complete = totalPercent == 100;
    final remaining = 100 - totalPercent;
    final progress = (totalPercent / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Toplam olasılık',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const Spacer(),
            Text(
              '%$totalPercent / %100',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: complete ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress,
            backgroundColor: const Color(0xFFEDE9FE),
            color: complete ? AppColors.success : AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          complete
              ? 'Dağılım hazır'
              : remaining > 0
              ? 'Dağılım henüz tamamlanmadı. Kalan: %$remaining'
              : 'Dağılım %100’ü aşıyor. Fazla: %${-remaining}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: complete ? AppColors.success : const Color(0xFFB45309),
          ),
        ),
      ],
    );
  }
}

class RewardWheelStickyBar extends StatelessWidget {
  const RewardWheelStickyBar({
    required this.canSave,
    required this.saving,
    required this.onReset,
    required this.onSave,
    super.key,
  });

  final bool canSave;
  final bool saving;
  final VoidCallback onReset;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: saving ? null : onReset,
                child: const Text('Değişiklikleri Sıfırla'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: canSave && !saving ? onSave : null,
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text(saving ? 'Kaydediliyor...' : 'Kaydet ve Yayınla'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RewardWheelGeneralSettings extends StatelessWidget {
  const RewardWheelGeneralSettings({
    required this.active,
    required this.useGlobalPool,
    required this.dailySpins,
    required this.cooldownHours,
    required this.perUserDailyLimit,
    required this.onActiveChanged,
    required this.onGlobalPoolChanged,
    required this.onDailySpinsChanged,
    required this.onCooldownChanged,
    required this.onPerUserLimitChanged,
    super.key,
  });

  final bool active;
  final bool useGlobalPool;
  final int dailySpins;
  final int cooldownHours;
  final int perUserDailyLimit;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<bool> onGlobalPoolChanged;
  final ValueChanged<int> onDailySpinsChanged;
  final ValueChanged<int> onCooldownChanged;
  final ValueChanged<int> onPerUserLimitChanged;

  @override
  Widget build(BuildContext context) {
    Widget numberField({
      required String label,
      required int value,
      required ValueChanged<int> onChanged,
    }) {
      return TextFormField(
        key: ValueKey('$label-$value'),
        initialValue: '$value',
        decoration: InputDecoration(labelText: label, isDense: true),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (raw) => onChanged(int.tryParse(raw) ?? value),
      );
    }

    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Çark aktif'),
          value: active,
          onChanged: onActiveChanged,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Global ödül havuzu kullanımı'),
          subtitle: const Text(
            'Kapalıyken kullanıcı yalnızca ilgili ödülleri görür. Oranlar değişmez.',
          ),
          value: useGlobalPool,
          onChanged: onGlobalPoolChanged,
        ),
        const SizedBox(height: 8),
        numberField(
          label: 'Günlük ücretsiz spin',
          value: dailySpins,
          onChanged: onDailySpinsChanged,
        ),
        const SizedBox(height: 8),
        numberField(
          label: 'Spin cooldown (saat)',
          value: cooldownHours,
          onChanged: onCooldownChanged,
        ),
        const SizedBox(height: 8),
        numberField(
          label: 'Kullanıcı başına günlük limit',
          value: perUserDailyLimit,
          onChanged: onPerUserLimitChanged,
        ),
      ],
    );
  }
}

class RewardWheelSettingsCard extends StatelessWidget {
  const RewardWheelSettingsCard({
    required this.child,
    this.title,
    super.key,
  });

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}
