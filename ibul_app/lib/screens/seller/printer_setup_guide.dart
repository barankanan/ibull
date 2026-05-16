import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PrinterSetupGuide — kurulum kılavuzu paneli
// ─────────────────────────────────────────────────────────────────────────────

class PrinterSetupGuide extends StatefulWidget {
  const PrinterSetupGuide({super.key});

  @override
  State<PrinterSetupGuide> createState() => _PrinterSetupGuideState();
}

class _PrinterSetupGuideState extends State<PrinterSetupGuide>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GuideTabBar(controller: _tabs),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _QuickStartTab(),
              _SupportedPrintersTab(),
              _TroubleshootingTab(),
              _RecommendationsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideTabBar extends StatelessWidget {
  const _GuideTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: controller,
        labelColor: const Color(0xFF8B5CF6),
        unselectedLabelColor: const Color(0xFF6B7280),
        indicatorColor: const Color(0xFF8B5CF6),
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Hızlı Kurulum'),
          Tab(text: 'Desteklenen'),
          Tab(text: 'Sorun Giderme'),
          Tab(text: 'Öneriler'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Hızlı Kurulum
// ─────────────────────────────────────────────────────────────────────────────

class _QuickStartTab extends StatelessWidget {
  const _QuickStartTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        _GuideHeader(
          icon: Icons.rocket_launch_outlined,
          title: 'Hızlı Kurulum',
          subtitle:
              '5 adımda termal yazıcınızı sisteme bağlayın. Toplam süre: ~10 dakika.',
        ),
        SizedBox(height: 20),
        _StepCard(
          number: 1,
          title: 'Python Bridge\'i Kur ve Başlat',
          content: _BridgeSetupContent(),
        ),
        SizedBox(height: 12),
        _StepCard(
          number: 2,
          title: 'CUPS\'ta Yazıcı Ekle (macOS)',
          content: _CupsSetupContent(),
        ),
        SizedBox(height: 12),
        _StepCard(
          number: 3,
          title: 'Bridge Ayarlarını Yapılandır',
          content: _BridgeConfigContent(),
        ),
        SizedBox(height: 12),
        _StepCard(
          number: 4,
          title: 'Yazıcıyı Sisteme Ekle',
          content: _AddPrinterContent(),
        ),
        SizedBox(height: 12),
        _StepCard(
          number: 5,
          title: 'Test Fişi Bas',
          content: _TestPrintContent(),
        ),
      ],
    );
  }
}

class _BridgeSetupContent extends StatelessWidget {
  const _BridgeSetupContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Terminal\'da proje klasörüne gidin ve aşağıdaki komutları çalıştırın:',
          style: TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.5),
        ),
        const SizedBox(height: 8),
        _CodeBlock(
          code: 'cd local_print_bridge\n'
              'pip install -r requirements.txt\n'
              'python -m local_print_bridge',
        ),
        const SizedBox(height: 8),
        const Text(
          'Bridge başarıyla çalışırsa http://127.0.0.1:3001/health adresinden "ok" yanıtı alırsınız.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.5),
        ),
      ],
    );
  }
}

class _CupsSetupContent extends StatelessWidget {
  const _CupsSetupContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Sistem Tercihleri → Yazıcılar ve Tarayıcılar (veya http://localhost:631) açın.\n'
          '2. "+" ile yeni yazıcı ekleyin.\n'
          '3. Raw sürücüsünü seçin (ESC/POS için en uygun).\n'
          '4. Kuyruğa bir isim verin (örn: Thermal80).',
          style: TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.7),
        ),
        const SizedBox(height: 8),
        _CodeBlock(
          code: '# CUPS üzerinden raw queue oluşturma\n'
              'lpadmin -p Thermal80 -E -v usb://... -m raw\n\n'
              '# Test yazdırma (terminal yerine uygulama/bridge üzerinden)\n'
              '# Not: echo | lp ile düz metin göndermek POS yazıcılarda garip karakterlere\n'
              '# ve kontrol kodlarına yol açabilir.\n'
              'curl -X POST http://127.0.0.1:3001/print/test',
        ),
      ],
    );
  }
}

class _BridgeConfigContent extends StatelessWidget {
  const _BridgeConfigContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'local_print_bridge/.env dosyasını oluşturun:',
          style: TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.5),
        ),
        const SizedBox(height: 8),
        _CodeBlock(
          code: 'BRIDGE_HOST=127.0.0.1\n'
              'BRIDGE_PORT=3001\n'
              'CUPS_RECEIPT_QUEUE=Thermal80\n'
              'CUPS_KITCHEN_QUEUE=Kitchen58\n'
              'PAPER_WIDTH_MM=80',
        ),
      ],
    );
  }
}

class _AddPrinterContent extends StatelessWidget {
  const _AddPrinterContent();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '"Yazıcı Ekle" butonuna basın ve açılan sihirbazı takip edin.\n'
      'Local Bridge bağlantısı seçin. Host: 127.0.0.1, Port: 3001.\n'
      'Route: /print/receipt (adisyon) veya /print/kitchen (mutfak).',
      style: TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.7),
    );
  }
}

class _TestPrintContent extends StatelessWidget {
  const _TestPrintContent();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Sihirbazın son adımında "Test Fişi Bas" butonuna tıklayın.\n'
      'Yazıcıdan bir test fişi çıkmalıdır. Test başarılıysa yazıcı otomatik aktif olur.',
      style: TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.7),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Desteklenen Yazıcılar
// ─────────────────────────────────────────────────────────────────────────────

class _SupportedPrintersTab extends StatelessWidget {
  const _SupportedPrintersTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _GuideHeader(
          icon: Icons.print_outlined,
          title: 'Desteklenen Yazıcılar',
          subtitle:
              'Sistem ESC/POS protokolünü kullanan termal yazıcıların büyük çoğunluğuyla uyumludur.',
        ),
        const SizedBox(height: 20),
        _SupportTable(
          title: 'Tam Desteklenen (Test Edildi)',
          color: const Color(0xFF10B981),
          bg: const Color(0xFFF0FDF4),
          rows: const [
            ('Epson TM-T20III', '80mm', 'USB/Network', '✓'),
            ('Epson TM-T88VI', '80mm', 'USB/Network/Bluetooth', '✓'),
            ('Epson TM-m30II', '80mm', 'Network/Bluetooth', '✓'),
            ('Star TSP100', '80mm', 'USB/Network', '✓'),
            ('Star TSP650II', '80mm', 'USB/Network', '✓'),
            ('Bixolon SRP-350', '80mm', 'USB/Network', '✓'),
          ],
        ),
        const SizedBox(height: 16),
        _SupportTable(
          title: 'Büyük İhtimalle Uyumlu (ESC/POS)',
          color: const Color(0xFFF59E0B),
          bg: const Color(0xFFFFFBEB),
          rows: const [
            ('Xprinter XP-N160II', '80mm', 'USB/Network', '~'),
            ('HOIN HOP-H58', '58mm', 'USB/Bluetooth', '~'),
            ('Rongta RP400', '80mm', 'USB/Network', '~'),
            ('iDPRT SP420', '80mm', 'USB/Network', '~'),
            ('TEROW TOE402', '80mm', 'Network', '~'),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEDE9F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  Icon(
                    Icons.help_outline_rounded,
                    size: 15,
                    color: Color(0xFF8B5CF6),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Yazıcınız Listede Yok mu?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4C1D95),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'ESC/POS standardını destekleyen her yazıcı büyük olasılıkla çalışır. '
                'Yazıcınız CUPS ile raw kuyruk oluşturmayı destekliyorsa sisteme ekleyebilirsiniz. '
                'Üreticinin belgelerinde "ESC/POS compatible" ibaresi arayın.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SupportTable extends StatelessWidget {
  const _SupportTable({
    required this.title,
    required this.color,
    required this.bg,
    required this.rows,
  });

  final String title;
  final Color color;
  final Color bg;
  final List<(String, String, String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(0.6),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                children: ['Model', 'Kağıt', 'Bağlantı', ''].map((h) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Text(
                      h,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  );
                }).toList(),
              ),
              ...rows.map(
                (r) => TableRow(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFF3F4F6)),
                    ),
                  ),
                  children: [r.$1, r.$2, r.$3, r.$4].map((cell) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Text(
                        cell,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF374151),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Sorun Giderme
// ─────────────────────────────────────────────────────────────────────────────

class _TroubleshootingTab extends StatelessWidget {
  const _TroubleshootingTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        _GuideHeader(
          icon: Icons.build_outlined,
          title: 'Sorun Giderme',
          subtitle: 'Yaygın sorunlar ve çözümleri.',
        ),
        SizedBox(height: 20),
        _TroubleshootCard(
          problem: 'Bridge Kapalı / Ulaşılamıyor',
          solution: '1. Terminal\'da python -m local_print_bridge çalıştırın.\n'
              '2. 127.0.0.1:3001/health adresini tarayıcıda açarak {"ok":true} gördüğünüzü kontrol edin.\n'
              '3. Güvenlik duvarı 3001 portunu engelliyor olabilir.',
          icon: Icons.cloud_off_outlined,
        ),
        SizedBox(height: 10),
        _TroubleshootCard(
          problem: 'Test Fişi Gönderildi Ama Yazıcıdan Çıktı Gelmiyor',
          solution: '1. CUPS kuyruğunu kontrol edin: http://localhost:631\n'
              '2. Kuyruğun "raw" modda ayarlı olduğundan emin olun.\n'
              '3. .env dosyasındaki CUPS_RECEIPT_QUEUE değerinin doğru yazıcı adını gösterdiğini kontrol edin.\n'
              '4. Yazıcı açık ve kağıt var mı?',
          icon: Icons.receipt_long_outlined,
        ),
        SizedBox(height: 10),
        _TroubleshootCard(
          problem: 'Türkçe Karakterler Bozuk Görünüyor',
          solution: '1. Yazıcı ayarlarında charset\'i CP857 veya CP1254 olarak değiştirin.\n'
              '2. .env dosyasına CHARSET=cp857 ekleyin.\n'
              '3. Bridge\'i yeniden başlatın.',
          icon: Icons.translate_rounded,
        ),
        SizedBox(height: 10),
        _TroubleshootCard(
          problem: 'Kağıt Kesilmiyor',
          solution: '1. Yazıcı ayarlarında "Otomatik Kesici" (Auto-cut) seçeneğini açın.\n'
              '2. Yazıcının auto-cutter donanımını desteklediğinden emin olun.',
          icon: Icons.content_cut_rounded,
        ),
        SizedBox(height: 10),
        _TroubleshootCard(
          problem: 'Network Yazıcısına Bağlanılamıyor',
          solution: '1. IP adresini ve portu (genelde 9100) doğrulayın.\n'
              '2. ping <ip_adresi> komutuyla yazıcıya ulaşılıp ulaşılmadığını test edin.\n'
              '3. Yazıcı ve bilgisayar aynı ağda mı?',
          icon: Icons.lan_outlined,
        ),
        SizedBox(height: 10),
        _TroubleshootCard(
          problem: 'Sipariş Geliyor Ama Yazdırılmıyor',
          solution: '1. Yazıcı Ayarları → Sipariş Dinleyici durumunu kontrol edin.\n'
              '2. Supabase realtime bağlantısı aktif mi?\n'
              '3. "Başarısız İşler" kartında hata detayına bakın.\n'
              '4. Yazıcı → İstasyon eşleştirmesini kontrol edin.',
          icon: Icons.sensors_off_outlined,
        ),
      ],
    );
  }
}

class _TroubleshootCard extends StatelessWidget {
  const _TroubleshootCard({
    required this.problem,
    required this.solution,
    required this.icon,
  });

  final String problem;
  final String solution;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ExpansionTile(
        leading: Icon(icon, size: 18, color: const Color(0xFF8B5CF6)),
        title: Text(
          problem,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          Text(
            solution,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF374151),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 4 — Öneriler
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendationsTab extends StatelessWidget {
  const _RecommendationsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        _GuideHeader(
          icon: Icons.star_outline_rounded,
          title: 'Öneriler',
          subtitle:
              'En iyi deneyim için önerilen kurulum yapılandırması ve donanımlar.',
        ),
        SizedBox(height: 20),
        _RecommendationCard(
          title: 'Donanım Önerisi',
          icon: Icons.print_rounded,
          items: [
            'Epson TM-T20III veya TM-T88VI — en stabil ve yaygın destek.',
            '80mm kağıt genişliği — daha fazla bilgi, daha iyi okunabilirlik.',
            'Network bağlantı — USB\'ye kıyasla daha güvenilir uzun süreli kullanımda.',
            'Auto-cutter destekli model — iş akışını hızlandırır.',
          ],
        ),
        SizedBox(height: 12),
        _RecommendationCard(
          title: 'Kurulum Önerisi',
          icon: Icons.settings_outlined,
          items: [
            'Local Bridge: CUPS raw queue kullanın — en esnek setup.',
            'Bridge\'i LaunchAgent olarak kaydedin (otomatik başlatma).',
            'Adisyon ve mutfak için ayrı yazıcı kullanın.',
            'Bridge loglarını takip edin: terminal çıktısını izleyin.',
          ],
        ),
        SizedBox(height: 12),
        _RecommendationCard(
          title: 'Güvenilirlik İpuçları',
          icon: Icons.verified_outlined,
          items: [
            'Test fişi basılmadan yazıcıyı aktif etmeyin.',
            'Network yazıcılara statik IP atayın — DHCP ile adres değişebilir.',
            'Bridge ve CUPS log\'larını düzenli kontrol edin.',
            'Yazıcı kağıt ve bakım aralıklarına dikkat edin.',
          ],
        ),
        SizedBox(height: 12),
        _RecommendationCard(
          title: 'Türkçe Destek',
          icon: Icons.translate_rounded,
          items: [
            'Charset: CP857 veya UTF-8 (CUPS altyapısına bağlı).',
            'Epson TM serisi Türkçe karakterleri yerel modda destekler.',
            'Bridge test fişi Türkçe karakter içerir — sorun varsa charset\'i değiştirin.',
          ],
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF374151),
                        height: 1.5,
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared guide widgets
// ─────────────────────────────────────────────────────────────────────────────

class _GuideHeader extends StatelessWidget {
  const _GuideHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F0FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: const Color(0xFF8B5CF6)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.content,
  });

  final int number;
  final String title;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F7FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B5CF6),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: content,
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              code,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFFCDD6F4),
                fontFamily: 'monospace',
                height: 1.6,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kopyalandı'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Icon(
              Icons.copy_rounded,
              size: 14,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}
