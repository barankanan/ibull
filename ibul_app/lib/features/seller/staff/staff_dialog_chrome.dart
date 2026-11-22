import 'package:flutter/material.dart';

import '../../../core/constants.dart';

/// Başlık: görev, personel adı, durum çipleri ve kapat.
class StaffDialogHeader extends StatelessWidget {
  const StaffDialogHeader({
    super.key,
    required this.title,
    required this.chips,
    required this.onClose,
    this.subtitle,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final List<String> chips;
  final VoidCallback? onClose;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 14, 8, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: compact ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ),
                if (chips.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final chip in chips)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.borderStrong),
                            ),
                            child: Text(
                              chip,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kapat',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// Sabit alt çubuk: gövdeden ayrıdır, içeriğin üstüne binmez.
class StaffDialogFooter extends StatelessWidget {
  const StaffDialogFooter({
    super.key,
    required this.busy,
    required this.changed,
    required this.canSave,
    required this.error,
    required this.onRevert,
    required this.onCancel,
    required this.onPreview,
    required this.onSave,
  });

  final bool busy;
  final bool changed;
  final bool canSave;
  final String? error;
  final VoidCallback onRevert;
  final VoidCallback onCancel;
  final VoidCallback onPreview;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null) _errorBanner(error!),
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 760
                ? _stacked()
                : _wide(),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('staff-dialog-error'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13, color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _revertButton() => TextButton.icon(
    onPressed: busy || !changed ? null : onRevert,
    icon: const Icon(Icons.undo, size: 18),
    label: const Text('Geri Al'),
    style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
  );

  Widget _hint() => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 8, color: AppColors.warning),
      SizedBox(width: 6),
      Flexible(
        child: Text(
          'Kaydedilmemiş değişiklikler var',
          style: TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
      ),
    ],
  );

  Widget _cancel({required bool outlined}) {
    final onPressed = busy ? null : onCancel;
    const size = Size(44, 48);
    return outlined
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(minimumSize: size),
            child: const Text('İptal'),
          )
        : TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(minimumSize: size),
            child: const Text('İptal'),
          );
  }

  Widget _preview() => OutlinedButton.icon(
    onPressed: busy ? null : onPreview,
    icon: const Icon(Icons.visibility_outlined, size: 18),
    label: const Text('Önizleme'),
    style: OutlinedButton.styleFrom(minimumSize: const Size(44, 48)),
  );

  Widget _save() => FilledButton(
    key: const ValueKey('staff-save-button'),
    onPressed: busy || !canSave ? null : onSave,
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
      disabledForegroundColor: Colors.white,
      minimumSize: const Size(110, 48),
    ),
    child: busy
        ? const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8),
              Flexible(child: Text('Kaydediliyor...')),
            ],
          )
        : const Text('Kaydet'),
  );

  Widget _wide() => Row(
    children: [
      Expanded(
        child: Row(
          children: [
            _revertButton(),
            const SizedBox(width: 8),
            if (changed) Flexible(child: _hint()),
          ],
        ),
      ),
      const SizedBox(width: 12),
      _cancel(outlined: false),
      const SizedBox(width: 8),
      _preview(),
      const SizedBox(width: 8),
      _save(),
    ],
  );

  Widget _stacked() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (changed)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _hint(),
        ),
      Wrap(
        spacing: 8,
        children: [_revertButton(), _preview()],
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(child: _cancel(outlined: true)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _save()),
        ],
      ),
    ],
  );
}
