import 'package:flutter/material.dart';

/// Read-only setup guide for the local print bridge.
/// Open via [showDialog<void>(context: ..., builder: (_) => ...)].
class PrinterGuideDialog extends StatelessWidget {
  const PrinterGuideDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.menu_book_outlined, size: 20, color: Color(0xFF7A2FF4)),
          SizedBox(width: 8),
          Text('Yazıcı Kurulum Kılavuzu'),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _GuideSection(
                step: '1',
                title: 'Köprü Servisi (server.py)',
                body: 'Bu bilgisayarda server.py (Python 3) çalışıyor olmalı. '
                    'Terminal üzerinden:\n\n'
                    '  python3 server.py\n\n'
                    'Köprü varsayılan olarak http://127.0.0.1:3001 adresini dinler.',
              ),
              SizedBox(height: 16),
              _GuideSection(
                step: '2',
                title: 'Otomatik Başlatma (LaunchAgent)',
                body: 'macOS\'ta köprüyü her açılışta otomatik başlatmak için '
                    'LaunchAgent kullanılır.\n'
                    'Kurulum adımları için docs/SELLER_DESKTOP_SETUP.md '
                    'belgesini inceleyin.',
              ),
              SizedBox(height: 16),
              _GuideSection(
                step: '3',
                title: 'Yazıcı Kaydı',
                body: '"Yazıcılar" sekmesinde "+ Yazıcı Ekle" düğmesine tıklayın.\n'
                    '• Bağlantı tipi: LocalCUPS (macOS) veya USB\n'
                    '• Kuyruk adını CUPS yönetim panelinden (http://localhost:631) '
                    'öğrenebilirsiniz.\n'
                    '• Yazıcıyı aktif hale getirmeyi unutmayın.',
              ),
              SizedBox(height: 16),
              _GuideSection(
                step: '4',
                title: 'Alan–Yazıcı Eşleştirme',
                body: '"Eşleştirme" sekmesinde alana yazıcı atayın.\n'
                    'Siparişler atanan yazıcıya otomatik yönlendirilir.',
              ),
              SizedBox(height: 16),
              _GuideSection(
                step: '5',
                title: 'Test',
                body: '"Yazıcılar" sekmesindeki "Test" düğmesi ile '
                    'varsayılan yazıcıya test fişi gönderebilirsiniz.',
              ),
              SizedBox(height: 16),
              _GuideSection(
                step: '!',
                title: 'Sorun Giderme',
                body: '• "Connection refused": Köprü servisi çalışmıyor.\n'
                    '• Fiş çıkmıyor: CUPS panelinde kuyruğun aktif olduğunu '
                    've kuyruk adının eşleştiğini doğrulayın.\n'
                    '• "assigned_roles" hatası: SUPABASE_PRINTERS_MIGRATION.sql '
                    'dosyasını Supabase SQL editöründe çalıştırın.',
              ),
              SizedBox(height: 12),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.step,
    required this.title,
    required this.body,
  });

  final String step;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step badge
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFEDE9FE),
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF7A2FF4),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4B5563),
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
