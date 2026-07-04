import 'package:flutter/material.dart';

import 'home_feature_form_card.dart';

class HomeFeatureBudgetSection extends StatelessWidget {
  const HomeFeatureBudgetSection({
    required this.startsAt,
    required this.endsAt,
    required this.durationDays,
    required this.dailyBudgetController,
    required this.totalBudgetController,
    required this.budgetType,
    required this.onBudgetTypeChanged,
    required this.onStartsAtChanged,
    required this.onEndsAtChanged,
    required this.onDailyBudgetChanged,
    required this.onTotalBudgetChanged,
    required this.estimatedFee,
    required this.estimatedImpressions,
    super.key,
  });

  final DateTime startsAt;
  final DateTime endsAt;
  final int durationDays;
  final TextEditingController dailyBudgetController;
  final TextEditingController totalBudgetController;
  final String budgetType;
  final ValueChanged<String> onBudgetTypeChanged;
  final ValueChanged<DateTime> onStartsAtChanged;
  final ValueChanged<DateTime> onEndsAtChanged;
  final VoidCallback onDailyBudgetChanged;
  final VoidCallback onTotalBudgetChanged;
  final double estimatedFee;
  final int estimatedImpressions;

  String _formatDate(DateTime d) => '${d.day}.${d.month}.${d.year}';

  @override
  Widget build(BuildContext context) {
    return HomeFeatureFormCard(
      title: 'Yayın Süresi ve Bütçe',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _DateTile(
                  label: 'Başlangıç tarihi',
                  value: _formatDate(startsAt),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: startsAt,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) onStartsAtChanged(d);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateTile(
                  label: 'Bitiş tarihi',
                  value: _formatDate(endsAt),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: endsAt,
                      firstDate: startsAt,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) onEndsAtChanged(d);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Text(
              durationDays > 0
                  ? '$durationDays gün yayınlanacak'
                  : 'Geçerli bir tarih aralığı seçin',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF166534),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'daily', label: Text('Günlük bütçe')),
              ButtonSegment(value: 'total', label: Text('Toplam bütçe')),
            ],
            selected: {budgetType},
            onSelectionChanged: (s) => onBudgetTypeChanged(s.first),
          ),
          const SizedBox(height: 14),
          if (budgetType == 'daily')
            TextField(
              controller: dailyBudgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Günlük bütçe (TRY)',
                border: OutlineInputBorder(),
                suffixText: 'TRY/gün',
              ),
              onChanged: (_) => onDailyBudgetChanged(),
            )
          else
            TextField(
              controller: totalBudgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Toplam bütçe (TRY)',
                border: OutlineInputBorder(),
                suffixText: 'TRY',
              ),
              onChanged: (_) => onTotalBudgetChanged(),
            ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tahmini değerler',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tahmini reklam ücreti: ${estimatedFee > 0 ? '${estimatedFee.toStringAsFixed(0)} TRY' : '-'}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Tahmini gösterim: ${estimatedImpressions > 0 ? estimatedImpressions : '-'}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Toplam bütçe: ${totalBudgetController.text.isNotEmpty ? '${totalBudgetController.text} TRY' : '-'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class HomeFeatureExtraSettingsSection extends StatelessWidget {
  const HomeFeatureExtraSettingsSection({
    required this.campaignNoteController,
    required this.autoCoverFirstBanner,
    required this.randomizeProducts,
    required this.rotateBanners,
    required this.onAutoCoverChanged,
    required this.onRandomizeChanged,
    required this.onRotateChanged,
    super.key,
  });

  final TextEditingController campaignNoteController;
  final bool autoCoverFirstBanner;
  final bool randomizeProducts;
  final bool rotateBanners;
  final ValueChanged<bool> onAutoCoverChanged;
  final ValueChanged<bool> onRandomizeChanged;
  final ValueChanged<bool> onRotateChanged;

  @override
  Widget build(BuildContext context) {
    return HomeFeatureFormCard(
      title: 'Ek Ayarlar',
      child: Column(
        children: [
          TextField(
            controller: campaignNoteController,
            decoration: const InputDecoration(
              labelText: 'Kampanya notu (opsiyonel)',
              helperText: 'Bu not admin onay ekranında görüntülenir.',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ana sayfada ilk görsel otomatik kapak olsun'),
            value: autoCoverFirstBanner,
            onChanged: onAutoCoverChanged,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Seçili ürünleri rastgele göster'),
            subtitle: const Text('Metadata olarak kaydedilir'),
            value: randomizeProducts,
            onChanged: onRandomizeChanged,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bannerları döngüsel göster'),
            value: rotateBanners,
            onChanged: onRotateChanged,
          ),
        ],
      ),
    );
  }
}
