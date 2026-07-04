import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../widgets/optimized_image.dart';

abstract final class StoreProfileDashboardTokens {
  static const cardRadius = 14.0;
  static const cardBorder = Color(0xFFE5E7EB);
  static const cardShadow = Color(0x08000000);
  static const pageGap = 14.0;
  static const inputBorder = Color(0xFFE2E8F0);
  static const inputFocusBorder = AppColors.primary;
}

class StoreProfileCompletionSnapshot {
  const StoreProfileCompletionSnapshot({
    required this.percent,
    required this.missingItems,
    this.tip,
  });

  final int percent;
  final List<String> missingItems;
  final String? tip;
}

StoreProfileCompletionSnapshot buildStoreProfileCompletion({
  required String storeName,
  required String phone,
  required String email,
  required String address,
  required String city,
  required String district,
  required String description,
  required String website,
  required String? coverUrl,
  required String? logoUrl,
}) {
  final checks = <String, bool>{
    'Mağaza adı': storeName.trim().isNotEmpty,
    'Telefon': phone.trim().isNotEmpty,
    'E-posta': email.trim().isNotEmpty,
    'Adres': address.trim().isNotEmpty,
    'İl / İlçe': city.trim().isNotEmpty && district.trim().isNotEmpty,
    'Kapak görseli': coverUrl != null && coverUrl.trim().isNotEmpty,
    'Logo': logoUrl != null && logoUrl.trim().isNotEmpty,
    'Açıklama': description.trim().isNotEmpty,
    'Website': website.trim().isNotEmpty,
  };
  final done = checks.values.where((v) => v).length;
  final total = checks.length;
  final percent = total == 0 ? 0 : ((done / total) * 100).round();
  final missing = checks.entries
      .where((e) => !e.value)
      .map((e) => e.key)
      .take(3)
      .toList(growable: false);

  return StoreProfileCompletionSnapshot(
    percent: percent,
    missingItems: missing,
    tip: percent < 100
        ? 'Logo ve kapak görseli mağaza güvenini artırır.'
        : 'Profiliniz vitrin için hazır görünüyor.',
  );
}

class SellerStoreProfileHero extends StatelessWidget {
  const SellerStoreProfileHero({
    super.key,
    required this.storeName,
    required this.slogan,
    required this.isStoreOpen,
    required this.completionPercent,
    required this.coverUrl,
    required this.logoUrl,
    this.localLogoBytes,
    required this.onPickCover,
    required this.onPickLogo,
    this.compact = false,
  });

  final String storeName;
  final String slogan;
  final bool isStoreOpen;
  final int completionPercent;
  final String? coverUrl;
  final String? logoUrl;
  final Uint8List? localLogoBytes;
  final VoidCallback onPickCover;
  final VoidCallback onPickLogo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final coverHeight = compact ? 150.0 : 190.0;
    final logoSize = compact ? 72.0 : 88.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StoreProfileDashboardTokens.cardRadius),
        border: Border.all(color: StoreProfileDashboardTokens.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: StoreProfileDashboardTokens.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: onPickCover,
                child: SizedBox(
                  height: coverHeight,
                  width: double.infinity,
                  child: coverUrl != null && coverUrl!.trim().isNotEmpty
                      ? OptimizedImage(
                          imageUrlOrPath: coverUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: coverHeight,
                          cacheWidth: OptimizedImage.maxDecodeDimension(),
                          cacheHeight: 300,
                          placeholder: Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: _coverPlaceholder(onPickCover),
                        )
                      : _coverPlaceholder(onPickCover),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: FilledButton.tonalIcon(
                  onPressed: onPickCover,
                  icon: const Icon(Icons.upload_rounded, size: 16),
                  label: const Text('Kapak Yükle'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                    foregroundColor: const Color(0xFF334155),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, compact ? 14 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Transform.translate(
                  offset: Offset(0, -(logoSize * 0.42)),
                  child: GestureDetector(
                    onTap: onPickLogo,
                    child: Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: _buildLogoContent(logoSize),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Transform.translate(
                    offset: Offset(0, compact ? -8 : -12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName.trim().isEmpty ? 'Mağaza Adı' : storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 17 : 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (slogan.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            slogan,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _heroChip(
                              label: isStoreOpen ? 'Mağaza açık' : 'Mağaza kapalı',
                              color: isStoreOpen
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF94A3B8),
                            ),
                            _heroChip(
                              label: '%$completionPercent tamamlandı',
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onPickLogo,
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text('Logo'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Önerilen: Kapak 1200×300px · Logo 500×500px',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoContent(double size) {
    if (localLogoBytes != null) {
      return Image.memory(localLogoBytes!, fit: BoxFit.cover);
    }
    if (logoUrl != null && logoUrl!.trim().isNotEmpty) {
      return OptimizedImage(
        imageUrlOrPath: logoUrl!,
        fit: BoxFit.cover,
        cacheWidth: 200,
        cacheHeight: 200,
        placeholder: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: _logoPlaceholder(size),
      );
    }
    return _logoPlaceholder(size);
  }

  Widget _logoPlaceholder(double size) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: size * 0.42,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _coverPlaceholder(VoidCallback onTap) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 34, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.upload_rounded, size: 16),
              label: const Text('Kapak Görseli Yükle'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class StoreProfileSectionCard extends StatelessWidget {
  const StoreProfileSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon = Icons.article_outlined,
    this.accent = AppColors.primary,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StoreProfileDashboardTokens.cardRadius),
        border: Border.all(color: StoreProfileDashboardTokens.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: StoreProfileDashboardTokens.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class StoreProfileCompletionCard extends StatelessWidget {
  const StoreProfileCompletionCard({super.key, required this.snapshot});

  final StoreProfileCompletionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return StoreProfileSectionCard(
      title: 'Profil Tamamlanma',
      subtitle: 'Eksik alanları hızlıca tamamlayın',
      icon: Icons.fact_check_outlined,
      accent: const Color(0xFF0EA5E9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '%${snapshot.percent}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'tamamlandı',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: (snapshot.percent / 100).clamp(0, 1),
              backgroundColor: const Color(0xFFF1F5F9),
              color: AppColors.primary,
            ),
          ),
          if (snapshot.missingItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Eksik: ${snapshot.missingItems.join(', ')}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
          if (snapshot.tip != null) ...[
            const SizedBox(height: 8),
            Text(
              snapshot.tip!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StoreProfileStickyActionBar extends StatelessWidget {
  const StoreProfileStickyActionBar({
    super.key,
    required this.isLoading,
    required this.onSave,
    required this.onRevert,
    this.hasUnsavedChanges = true,
    this.compact = false,
  });

  final bool isLoading;
  final VoidCallback onSave;
  final VoidCallback onRevert;
  final bool hasUnsavedChanges;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 520 || compact;
          final info = Row(
            children: [
              Icon(
                hasUnsavedChanges
                    ? Icons.edit_note_rounded
                    : Icons.check_circle_outline_rounded,
                size: 18,
                color: hasUnsavedChanges
                    ? const Color(0xFFD97706)
                    : const Color(0xFF059669),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasUnsavedChanges
                      ? 'Kaydedilmemiş değişiklikler olabilir'
                      : 'Değişiklikler kaydedildi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          );
          final actions = LayoutBuilder(
            builder: (context, actionConstraints) {
              final stackButtons = actionConstraints.maxWidth < 420 || compact;
              final revertButton = SizedBox(
                width: stackButtons ? double.infinity : null,
                child: OutlinedButton(
                  onPressed: isLoading ? null : onRevert,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: const Text('Değişiklikleri Geri Al'),
                ),
              );
              final saveButton = SizedBox(
                width: stackButtons ? double.infinity : null,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : onSave,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 16),
                  label: Text(
                    isLoading ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                ),
              );

              if (stackButtons) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    revertButton,
                    const SizedBox(height: 8),
                    saveButton,
                  ],
                );
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  revertButton,
                  const SizedBox(width: 8),
                  saveButton,
                ],
              );
            },
          );

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 10),
                actions,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class StoreProfileMediaSectionHeader extends StatelessWidget {
  const StoreProfileMediaSectionHeader({
    super.key,
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StoreProfileDashboardTokens.cardRadius),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(StoreProfileDashboardTokens.cardRadius),
            border: Border.all(color: StoreProfileDashboardTokens.cardBorder),
            boxShadow: const [
              BoxShadow(
                color: StoreProfileDashboardTokens.cardShadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.perm_media_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Medya ve İçerikler',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expanded
                          ? 'Galeri, duyuru ve video alanları açık'
                          : 'Galeri, duyuru ve videoları buradan yönetin',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration storeProfileInputDecoration({
  required String hint,
  String? prefixText,
  String? errorText,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: StoreProfileDashboardTokens.inputBorder),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    prefixText: prefixText,
    errorText: errorText,
    filled: true,
    fillColor: const Color(0xFFFCFCFD),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(
        color: StoreProfileDashboardTokens.inputFocusBorder,
        width: 1.4,
      ),
    ),
    errorBorder: border.copyWith(
      borderSide: const BorderSide(color: Color(0xFFEF4444)),
    ),
    focusedErrorBorder: border.copyWith(
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.4),
    ),
  );
}

TextStyle get storeProfileFieldLabelStyle => const TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: Color(0xFF475569),
);
