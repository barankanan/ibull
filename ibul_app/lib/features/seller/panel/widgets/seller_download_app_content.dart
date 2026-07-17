import 'package:flutter/material.dart';

import '../../../../core/config/runtime_config.dart';
import '../../../../utils/browser_file_download.dart';

/// Seller panel "Satıcı Uygulamasını İndir" module content.
class SellerDownloadAppContent extends StatelessWidget {
  const SellerDownloadAppContent({super.key});

  /// Link null/boşsa kırık URL açmak yerine kullanıcıya açık mesaj gösterir.
  static void openDownloadOrExplain(BuildContext context, String? url) {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İndirme linki hazırlanıyor.')),
      );
      return;
    }
    BrowserFileDownload.openExternalUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 720;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Satıcı Uygulamasını İndir',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Adisyon, mutfak fişi ve yerel yazdırma işlemleri için masaüstü uygulamasını kullanın.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              if (twoColumns)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildWindowsCard(context)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMacCard(context)),
                  ],
                )
              else ...[
                _buildWindowsCard(context),
                const SizedBox(height: 12),
                _buildMacCard(context),
              ],
              const SizedBox(height: 24),
              _buildWhyDesktopSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWindowsCard(BuildContext context) {
    return _DownloadPlatformCard(
      icon: Icons.desktop_windows_outlined,
      title: 'Windows',
      subtitle: 'Windows Satıcı Uygulaması',
      description: 'Yerel yazıcı desteği ile hızlı ve kararlı yazdırma.\n(Güncel sürüm)',
      buttonLabel: 'Windows için İndir',
      onDownload: () => openDownloadOrExplain(
        context,
        AppRuntimeConfig.sellerDesktopWindowsDownloadUrlOrNull,
      ),
    );
  }

  Widget _buildMacCard(BuildContext context) {
    return _DownloadPlatformCard(
      icon: Icons.laptop_mac_outlined,
      title: 'macOS',
      subtitle: 'MacBook Satıcı Uygulaması',
      description: 'Yerel yazıcı desteği ve kesintisiz masaüstü deneyimi.\n(Güncel sürüm)',
      buttonLabel: 'MacBook için İndir',
      onDownload: () => openDownloadOrExplain(
        context,
        AppRuntimeConfig.sellerDesktopMacosDownloadUrlOrNull,
      ),
    );
  }

  Widget _buildWhyDesktopSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Neden masaüstü uygulama kurmalısınız?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 10),
          _WhyDesktopBullet(
            text: 'Tarayıcı baskısına göre çok daha stabil çalışır',
          ),
          _WhyDesktopBullet(
            text: 'Mutfak ve adisyon fişlerini anında, beklemeden yazdırır',
          ),
          _WhyDesktopBullet(
            text: 'İşletmenizdeki USB veya Ağ yazıcılarıyla tam uyumludur',
          ),
          _WhyDesktopBullet(
            text: 'Profesyonel restoran yönetimi için her zaman tavsiye edilir',
          ),
        ],
      ),
    );
  }
}

class _DownloadPlatformCard extends StatelessWidget {
  const _DownloadPlatformCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.buttonLabel,
    required this.onDownload,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final String buttonLabel;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _WhyDesktopBullet extends StatelessWidget {
  const _WhyDesktopBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_outline,
              size: 16,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4B5563),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
