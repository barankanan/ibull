import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants.dart';
import '../../../services/auth_service.dart';
import '../data/vehicle_listing_repository.dart';
import '../domain/vehicle_catalog.dart';
import '../domain/vehicle_listing_validation.dart';
import '../models/vehicle_enums.dart';
import '../navigation/vehicle_routes.dart';
import '../widgets/vehicle_editor_side_panel.dart';
import '../widgets/vehicle_listing_detail_view.dart';
import '../widgets/vehicle_listing_preview.dart';
import '../widgets/vehicle_wizard_chrome.dart';
import 'wizard/vehicle_wizard_content_step.dart';
import 'wizard/vehicle_wizard_details_step.dart';
import 'wizard/vehicle_wizard_identity_step.dart';
import 'wizard/vehicle_wizard_listing_step.dart';
import 'wizard/vehicle_wizard_photos_step.dart';
import 'wizard/vehicle_wizard_pricing_step.dart';
import 'wizard/vehicle_wizard_session.dart';
import 'wizard/vehicle_wizard_shell.dart';

class VehicleAddWizardPage extends StatefulWidget {
  const VehicleAddWizardPage({super.key, this.listingId});

  final String? listingId;

  @override
  State<VehicleAddWizardPage> createState() => _VehicleAddWizardPageState();
}

class _VehicleAddWizardPageState extends State<VehicleAddWizardPage> {
  late final VehicleWizardSession _session;
  final _title = TextEditingController();
  final _description = TextEditingController();
  int _step = 0;
  bool _loading = true;
  bool _hydrationCompleted = false;
  bool _submitted = false;
  bool _dirty = false;
  String? _loadError;

  static const _steps = [
    'İlan',
    'Araç',
    'Teknik',
    'Durum & Donanım',
    'Fiyat',
    'Fotoğraflar',
    'Önizleme',
  ];
  static const _previewStep = 6;

  String? _busy;
  bool get _isEdit => widget.listingId != null || _session.listingId != null;
  bool get _isLive =>
      _session.draft.publishStatus == VehicleListingStatus.active;
  bool get _canMutate =>
      _busy == null && (widget.listingId == null || _hydrationCompleted);

  @override
  void initState() {
    super.initState();
    _session = VehicleWizardSession(
      listingId: widget.listingId,
      sellerId: AuthService().currentUser?.id,
    );
    _boot();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    if (mounted && !_loading) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      await _session.loadExisting();
      _title.text = _session.draft.displayTitle;
      _description.text = _session.draft.description ?? '';
      _hydrationCompleted = _session.hydrationCompleted;
      _loadError = null;
    } catch (error, stack) {
      debugPrint('[vehicle] wizard boot failed: $error\n$stack');
      _loadError = VehiclePublishErrorMapper.loadFailure(error);
      _hydrationCompleted = false;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _markDirty() {
    if (!_session.draft.titleManual &&
        _title.text != _session.draft.displayTitle) {
      _title.text = _session.draft.displayTitle;
    }
    _dirty = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return VehicleWizardLoadError(onRetry: _boot);
    }
    if (_submitted) {
      return VehicleWizardSubmitSuccess(
        canPreview: _session.listingId != null,
        onPreview: () => VehicleRoutes.openDetail(
          context,
          _session.listingId!,
          preview: true,
        ),
        onBack: () => Navigator.pop(context, true),
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 960;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          title: VehicleWizardTitle(isEdit: _isEdit, draft: _session.draft),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _canMutate ? _saveDraft : null,
                      child: Text(
                        _busy == 'save'
                            ? 'Kaydediliyor...'
                            : (_isLive
                                  ? 'Değişiklikleri Kaydet'
                                  : 'Taslak Kaydet'),
                      ),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton(
                      onPressed: _canMutate ? _openPreview : null,
                      child: Text(
                        _busy == 'preview'
                            ? 'Hazırlanıyor...'
                            : (_isLive ? 'Önizle' : 'İlanı Önizle'),
                      ),
                    ),
                    if (!_isLive) ...[
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _canMutate ? _submit : null,
                        child: Text(
                          _busy == 'submit'
                              ? 'Gönderiliyor...'
                              : 'Onaya Gönder',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_session.draft.isRejected)
              Material(
                color: AppColors.dangerSoft,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'İlan reddedildi. Admin notu: ${_session.draft.rejectionNote}',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            VehicleWizardStepper(
              labels: _steps,
              index: _step,
              onSelect: (i) => setState(() => _step = i),
            ),
            if (_session.lastSavedAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Son kaydetme: ${_clock(_session.lastSavedAt!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
            Expanded(child: _workspace(wide)),
            _navBar(),
          ],
        ),
      ),
    );
  }

  Widget _workspace(bool wide) {
    final form = _body();
    if (!wide) return form;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 72, child: form),
            Expanded(
              flex: 28,
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 8, 16, 24),
                  child: VehicleEditorSidePanel(
                    draft: _session.draft,
                    photos: _session.photos,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_step) {
      case 0:
        return VehicleWizardListingStep(
          draft: _session.draft,
          titleController: _title,
          descriptionController: _description,
          onChanged: _markDirty,
        );
      case 1:
        return VehicleWizardIdentityStep(
          draft: _session.draft,
          onChanged: _markDirty,
        );
      case 2:
        return VehicleWizardDetailsStep(
          draft: _session.draft,
          onChanged: _markDirty,
        );
      case 3:
        return VehicleWizardContentStep(
          draft: _session.draft,
          onChanged: _markDirty,
        );
      case 4:
        return VehicleWizardPricingStep(
          draft: _session.draft,
          onChanged: _markDirty,
        );
      case 5:
        return VehicleWizardPhotosStep(
          photos: _session.photos,
          onAdd: _pickAndUpload,
          onDelete: (photo) async {
            await _session.deletePhoto(photo);
            _markDirty();
          },
          onCover: (photo) async {
            try {
              await _session.setCover(photo);
            } catch (error, stack) {
              debugPrint('[vehicle] set cover failed: $error\n$stack');
              _snack('Ana fotoğraf güncellenemedi.');
            }
            _markDirty();
          },
          onRetry: () {
            _snack('Aynı fotoğrafı galeriden yeniden seçin.');
            _pickAndUpload();
          },
          onMove: (from, to) async {
            await _session.movePhoto(from, to);
            _markDirty();
          },
        );
      default:
        final preview = VehicleListingPreview.fromDraft(
          draft: _session.draft,
          photos: _session.photos,
          sellerId: _session.sellerId ?? '',
          listingId: _session.listingId,
          gallery: _session.gallery,
        );
        return VehicleListingDetailView(
          listing: preview.listing,
          previewMode: true,
        );
    }
  }

  Widget _navBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            if (_step > 0)
              OutlinedButton(
                onPressed: _busy != null
                    ? null
                    : () => setState(() => _step -= 1),
                child: const Text('Geri'),
              ),
            const Spacer(),
            if (_step < _steps.length - 1)
              FilledButton(
                onPressed: _canMutate ? _next : null,
                child: const Text('Devam Et'),
              ),
          ],
        ),
      ),
    );
  }

  void _syncDraft() {
    _session.draft.title = _title.text;
    if (_title.text.trim().isNotEmpty) _session.draft.titleManual = true;
    _session.draft.description = _description.text;
  }

  String _clock(DateTime value) {
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _openPreview() async {
    _syncDraft();
    setState(() {
      _busy = 'preview';
      _step = _previewStep;
    });
    await Future<void>.delayed(Duration.zero);
    if (mounted) setState(() => _busy = null);
  }

  Future<void> _next() async {
    _syncDraft();
    final issues = VehicleListingValidator.validateStep(
      _step,
      draft: _session.draft,
      uploadedPhotoCount: _session.readyPhotoCount,
    );
    if (issues.isNotEmpty) {
      _snack(issues.first.message);
      return;
    }
    setState(() => _busy = 'save');
    try {
      await _session.persist(
        title: _title.text,
        description: _description.text,
      );
      if (!mounted) return;
      setState(() {
        _step += 1;
        _busy = null;
        _dirty = false;
        if (!_session.draft.titleManual) {
          _session.draft.applySuggestedTitleIfNeeded();
          _title.text = _session.draft.displayTitle;
        }
      });
    } catch (error, stack) {
      debugPrint('[vehicle] wizard next failed: $error\n$stack');
      if (!mounted) return;
      setState(() => _busy = null);
      _snack(VehiclePublishErrorMapper.fromObject(error));
    }
  }

  Future<void> _saveDraft() async {
    _syncDraft();
    setState(() => _busy = 'save');
    try {
      await _session.persist(
        title: _title.text,
        description: _description.text,
      );
      if (!mounted) return;
      setState(() {
        _busy = null;
        _dirty = false;
      });
      _snack('Taslak kaydedildi.');
    } catch (error, stack) {
      debugPrint('[VehicleListing][saveDraft] result=failed $error\n$stack');
      if (!mounted) return;
      setState(() => _busy = null);
      _snack(
        'Taslak kaydedilemedi. ${VehiclePublishErrorMapper.fromObject(error)}',
      );
    }
  }

  Future<void> _submit() async {
    _syncDraft();
    final issues = VehicleListingValidator.validatePublish(
      draft: _session.draft,
      uploadedPhotoCount: _session.readyPhotoCount,
    );
    if (issues.isNotEmpty) {
      setState(() => _step = issues.first.step);
      _snack(issues.first.message);
      return;
    }
    setState(() => _busy = 'submit');
    try {
      await _session.submitForReview();
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _busy = null;
        _dirty = false;
      });
    } catch (error, stack) {
      debugPrint('[VehicleListing][submitReview] result=failed $error\n$stack');
      if (!mounted) return;
      setState(() => _busy = null);
      final mapped = error is VehicleRepositoryException
          ? error.message
          : VehiclePublishErrorMapper.fromObject(error);
      _snack('İlan gönderilemedi. $mapped');
    }
  }

  Future<void> _confirmLeave() async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydedilmemiş değişiklikleriniz var.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Kaydetmeden Çık'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Kaydet ve Çık'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'discard') {
      _dirty = false;
      Navigator.pop(context);
    } else if (action == 'save') {
      if (!_canMutate) {
        _snack('İlan bilgileri yüklenemedi. Lütfen tekrar deneyin.');
        return;
      }
      await _session.persist(
        title: _title.text,
        description: _description.text,
      );
      if (!mounted) return;
      _dirty = false;
      Navigator.pop(context, true);
    }
  }

  Future<void> _pickAndUpload() async {
    if (_session.photos.length >= VehicleCatalog.maxPhotos) return;
    final files = await ImagePicker().pickMultiImage(
      imageQuality: 72,
      maxWidth: 1600,
    );
    if (files.isEmpty) return;
    setState(() => _busy = 'save');
    try {
      await _session.ensureDraft();
    } catch (error, stack) {
      debugPrint('[vehicle] draft before upload failed: $error\n$stack');
      if (mounted) {
        setState(() => _busy = null);
        _snack(VehiclePublishErrorMapper.fromObject(error));
      }
      return;
    }
    if (mounted) setState(() => _busy = null);
    final remaining = VehicleCatalog.maxPhotos - _session.photos.length;
    for (final file in files.take(remaining)) {
      await _session.upload(file);
      if (mounted) setState(() => _dirty = true);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
