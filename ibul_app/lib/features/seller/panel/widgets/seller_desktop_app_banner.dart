import 'package:flutter/material.dart';

import '../../../../core/config/runtime_config.dart';
import 'seller_download_app_content.dart';

/// Dismissible web-only banner promoting the seller desktop app.
class SellerDesktopAppBanner extends StatelessWidget {
  const SellerDesktopAppBanner({
    super.key,
    required this.onDismiss,
    this.onOpenDownloadPage,
  });

  final VoidCallback onDismiss;
  final VoidCallback? onOpenDownloadPage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.speed_outlined,
                size: 20,
                color: Color(0xFF6D28D9),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Satıcı uygulamasını indirin, işlemlerinizi hızlandırın.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4C1D95),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Kapat',
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: Color(0xFF6D28D9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 28),
            child: Text(
              'Adisyon, mutfak fişi ve yerel yazdırma işlemleri masaüstü uygulamasıyla (Windows/macOS) çok daha kararlı ve hızlı çalışır.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF4C1D95),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => SellerDownloadAppContent.openDownloadOrExplain(
                    context,
                    AppRuntimeConfig.sellerDesktopWindowsDownloadUrlOrNull,
                  ),
                  icon: const Icon(Icons.desktop_windows_outlined, size: 18),
                  label: const Text('Windows için İndir'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6D28D9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => SellerDownloadAppContent.openDownloadOrExplain(
                    context,
                    AppRuntimeConfig.sellerDesktopMacosDownloadUrlOrNull,
                  ),
                  icon: const Icon(Icons.laptop_mac_outlined, size: 18),
                  label: const Text('MacBook için İndir'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6D28D9),
                    side: const BorderSide(color: Color(0xFF6D28D9)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (onOpenDownloadPage != null)
                  TextButton.icon(
                    onPressed: onOpenDownloadPage,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text(
                      'Tüm İndirme Seçenekleri',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6D28D9),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
