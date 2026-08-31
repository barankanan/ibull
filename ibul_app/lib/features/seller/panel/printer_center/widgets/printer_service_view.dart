import 'package:flutter/material.dart';

import '../printer_service_status.dart';

class PrinterServicePanel extends StatelessWidget {
  const PrinterServicePanel({
    super.key,
    required this.snapshot,
    required this.onRefresh,
    required this.onTest,
  });

  final PrinterServiceSnapshot snapshot;
  final VoidCallback onRefresh;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final statusColor = snapshot.statusColor;
    final isBusy = snapshot.isBusy;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.print_outlined, color: statusColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Yazıcı Servisi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Durum ve kısa test işlemleri',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isBusy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Durum',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  snapshot.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  snapshot.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Yenile'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isBusy ? null : onTest,
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('Test Yazdır'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Bu bilgisayarda yazıcı servisi açık olmalıdır.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Servis kapalıysa kurulum dökümanındaki tek seferlik başlatma adımlarını uygulayın.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class PrinterServiceStatusBadge extends StatelessWidget {
  const PrinterServiceStatusBadge({super.key, required this.snapshot});

  final PrinterServiceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final color = snapshot.statusColor;
    return Tooltip(
      message: snapshot.message,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              snapshot.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrinterServiceCompactBar extends StatelessWidget {
  const PrinterServiceCompactBar({
    super.key,
    required this.snapshot,
    required this.statusBadge,
    required this.onOpen,
  });

  final PrinterServiceSnapshot snapshot;
  final Widget statusBadge;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isChecking = snapshot.isChecking;
    final color = snapshot.statusColor;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            if (isChecking)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFF9CA3AF),
                  ),
                ),
              )
            else
              Icon(Icons.print_outlined, size: 14, color: color),
            const SizedBox(width: 6),
            const Text(
              'Yazıcı Servisi',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(width: 8),
            statusBadge,
            const Spacer(),
            const Text(
              'Detay',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showPrinterServiceSheet({
  required BuildContext context,
  required PrinterServiceSnapshot snapshot,
  required VoidCallback onRefresh,
  required VoidCallback onTest,
}) {
  final statusColor = snapshot.statusColor;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.print_outlined, color: statusColor, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Yazıcı Servisi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                  iconSize: 20,
                  tooltip: 'Kapat',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.20),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snapshot.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          snapshot.message,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            height: 1.35,
                          ),
                        ),
                        if (snapshot.lastSuccessAgo != null &&
                            snapshot.isAvailable != true) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Son başarılı bağlantı: ${snapshot.lastSuccessAgo}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onRefresh();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Yenile'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onTest();
                    },
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text('Test Yazdır'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Bu bilgisayarda yazıcı servisi açık olmalıdır. '
              'Kapalıysa kurulum dökümanındaki başlatma adımlarını uygulayın. '
              'Servis durumu 30 saniyede bir otomatik kontrol edilir.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    },
  );
}
