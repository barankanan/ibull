import 'package:flutter/material.dart';

import '../widgets/skeleton_loading.dart';

/// First-frame landing shell: logo, search, category skeleton — no heavy home imports.
class WebHomeShell extends StatelessWidget {
  const WebHomeShell({
    super.key,
    this.errorText,
    this.onRetry,
  });

  final String? errorText;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _HeaderShell(),
            if (hasError) _ErrorBanner(text: errorText!, onRetry: onRetry),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: const [
                  SkeletonLoading(width: double.infinity, height: 44, borderRadius: 12),
                  SizedBox(height: 12),
                  SkeletonLoading(width: double.infinity, height: 72, borderRadius: 12),
                  SizedBox(height: 12),
                  SkeletonLoading(width: double.infinity, height: 160, borderRadius: 12),
                  SizedBox(height: 12),
                  SkeletonLoading(width: double.infinity, height: 220, borderRadius: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderShell extends StatelessWidget {
  const _HeaderShell();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // Açılış kabuğunda ikon ve spinner YOK.
      // HTML loader ilk frame'de silindiği için kullanıcının gerçekte gördüğü
      // "yükleniyor" ekranı burasıydı: mor gradient storefront ikonu +
      // CircularProgressIndicator. İkisi de kaldırıldı — geriye yalnız sade
      // "İbul" kelime-markası ve içerik iskeleti kalıyor.
      // Kart yüksekliği (64), beyaz zemin, köşe yarıçapı ve gölge aynen
      // korundu; layout/responsive davranış değişmiyor.
      child: const Row(
        children: [
          Expanded(
            child: Text(
              'İbul',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text, style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 13)),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
            ),
          ],
        ],
      ),
    );
  }
}

/// @deprecated Use [WebHomeShell].
typedef WebHomeBootShell = WebHomeShell;
