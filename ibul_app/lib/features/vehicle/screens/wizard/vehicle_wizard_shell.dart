import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../widgets/ibul_page_state.dart';
import '../../models/vehicle_enums.dart';
import '../../models/vehicle_wizard_draft.dart';

class VehicleWizardTitle extends StatelessWidget {
  const VehicleWizardTitle({
    super.key,
    required this.isEdit,
    required this.draft,
  });

  final bool isEdit;
  final VehicleWizardDraft draft;

  @override
  Widget build(BuildContext context) {
    final badge = _badge(draft);
    return Row(
      children: [
        Flexible(
          child: Text(
            isEdit ? 'İlanı Düzenle' : 'Yeni Araç İlanı',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badge.$2),
            ),
            child: Text(
              badge.$1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: badge.$2,
              ),
            ),
          ),
        ],
      ],
    );
  }

  static (String, Color)? _badge(VehicleWizardDraft draft) {
    if (draft.isRejected) return ('Reddedildi', AppColors.danger);
    switch (draft.publishStatus) {
      case VehicleListingStatus.pendingReview:
        return ('Onay Bekliyor', AppColors.primary);
      case VehicleListingStatus.active:
        return ('Yayında', AppColors.success);
      default:
        return null;
    }
  }
}

class VehicleWizardSubmitSuccess extends StatelessWidget {
  const VehicleWizardSubmitSuccess({
    super.key,
    required this.canPreview,
    required this.onPreview,
    required this.onBack,
  });

  final bool canPreview;
  final VoidCallback onPreview;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        title: const Text('İncelemeye gönderildi'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.hourglass_top, color: AppColors.primary, size: 56),
            const SizedBox(height: 12),
            const Text(
              'İlanınız incelemeye gönderildi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Admin onayından sonra İBUL\'da yayınlanacaktır.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: canPreview ? onPreview : null,
              child: const Text('İlan Önizleme'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onBack,
              child: const Text('Araçlarıma Dön'),
            ),
          ],
        ),
      ),
    );
  }
}

class VehicleWizardLoadError extends StatelessWidget {
  const VehicleWizardLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        title: const Text('İlanı Düzenle'),
      ),
      body: IbulPageState.error(
        title: 'İlan bilgileri yüklenemedi. Lütfen tekrar deneyin.',
        onAction: onRetry,
      ),
    );
  }
}
