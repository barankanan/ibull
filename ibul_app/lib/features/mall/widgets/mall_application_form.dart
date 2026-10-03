import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants.dart';
import '../auth/mall_auth_session.dart';
import '../models/mall_application.dart';
import '../services/mall_application_repository.dart';
import '../services/mall_picked_file.dart';
import '../../../widgets/image_cropper_widget.dart';
import 'mall_application_account_step.dart';
import 'mall_application_presentation.dart';
import 'mall_form_chrome.dart';
import 'mall_location_picker.dart';

class MallApplicationWizard extends StatefulWidget {
  const MallApplicationWizard({
    super.key,
    required this.repository,
    required this.onFinished,
    this.existing,
    this.initialStep = 0,
    this.preferSignIn = false,
    this.forceSignedIn,
    this.session,
  });

  final MallApplicationRepository repository;
  final MallApplication? existing;
  final VoidCallback onFinished;
  final int initialStep;
  final bool preferSignIn;
  final bool? forceSignedIn;

  /// AVM account session; the wizard never signs into the customer session.
  final MallAuthSession? session;

  @override
  State<MallApplicationWizard> createState() => _MallApplicationWizardState();
}

class _MallApplicationWizardState extends State<MallApplicationWizard> {
  static const _steps = [
    'Hesap',
    'İşletme',
    'AVM',
    'Konum',
    'Görseller & Belgeler',
    'Önizleme',
  ];

  MallAuthSession get _auth => widget.session ?? MallAuthSession.instance;
  late final TextEditingController _givenName;
  late final TextEditingController _surname;
  late final TextEditingController _email;
  late final TextEditingController _accountPhone;
  late final TextEditingController _password;
  late final TextEditingController _confirm;
  late final TextEditingController _name;
  late final TextEditingController _legal;
  late final TextEditingController _tax;
  late final TextEditingController _taxOffice;
  late final TextEditingController _mersis;
  late final TextEditingController _registry;
  late final TextEditingController _kep;
  late final TextEditingController _phone;
  late final TextEditingController _website;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late final TextEditingController _address;
  late final TextEditingController _person;
  late final TextEditingController _title;
  late final TextEditingController _floors;

  String? _applicationId;
  double? _latitude;
  double? _longitude;
  final Map<String, String> _slotPaths = {};
  final Map<String, int> _documentSizes = {};
  bool _existingAccount = false;
  bool? _signedInOverride;
  String? _logoUrl;
  String? _coverUrl;
  Uint8List? _localLogoBytes;
  Uint8List? _localCoverBytes;
  late int _step;
  bool _busy = false;
  String? _busyMedia;
  String? _error;
  int? _errorStep;
  final Map<String, FocusNode> _focusNodes = {};
  final Set<int> _revealedSteps = {};

  bool get _resubmit =>
      widget.existing?.status == MallApplicationStatus.needsInfo;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _applicationId = existing?.id;
    _name = TextEditingController(text: existing?.mallName ?? '');
    _legal = TextEditingController(text: existing?.legalName ?? '');
    _tax = TextEditingController(text: existing?.taxNumber ?? '');
    _taxOffice = TextEditingController(text: existing?.taxOffice ?? '');
    _mersis = TextEditingController(text: existing?.mersisNo ?? '');
    _registry = TextEditingController(text: existing?.tradeRegistryNo ?? '');
    _kep = TextEditingController(text: existing?.kepAddress ?? '');
    _phone = TextEditingController(text: existing?.phone ?? '');
    _website = TextEditingController(text: existing?.website ?? '');
    _city = TextEditingController(text: existing?.city ?? '');
    _district = TextEditingController(text: existing?.district ?? '');
    _address = TextEditingController(text: existing?.addressText ?? '');
    _person = TextEditingController(text: existing?.authorizedPersonName ?? '');
    _title = TextEditingController(text: existing?.authorizedPersonTitle ?? '');
    _floors = TextEditingController(
      text: existing?.declaredFloorCount?.toString() ?? '',
    );
    final account = _accountSeed(existing);
    _givenName = TextEditingController(text: account.$1);
    _surname = TextEditingController(text: account.$2);
    _email = TextEditingController(text: account.$3);
    _accountPhone = TextEditingController(text: account.$4);
    _password = TextEditingController();
    _confirm = TextEditingController();
    _existingAccount = widget.preferSignIn && !_isSignedIn;
    _latitude = existing?.latitude;
    _longitude = existing?.longitude;
    _restoreDocuments(existing?.documentPaths ?? const []);
    _logoUrl = existing?.logoUrl;
    _coverUrl = existing?.coverUrl;
    _step = widget.initialStep.clamp(0, _steps.length - 1);
  }

  (String, String, String, String) _accountSeed(MallApplication? existing) {
    final user = _sessionUser;
    final display = user?.userMetadata?['display_name']?.toString().trim() ??
        user?.userMetadata?['name']?.toString().trim() ??
        existing?.authorizedPersonName ??
        '';
    final parts = display.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    final given = parts.isEmpty ? '' : parts.first;
    final surname = parts.length < 2 ? '' : parts.sublist(1).join(' ');
    final email = (user?.email?.isNotEmpty ?? false)
        ? user!.email!
        : existing?.authorizedPersonEmail ?? '';
    final sessionPhone = (user?.phone?.isNotEmpty ?? false)
        ? user!.phone!
        : user?.userMetadata?['phone']?.toString() ?? '';
    final phone = sessionPhone.isNotEmpty
        ? sessionPhone
        : existing?.authorizedPersonPhone ?? '';
    return (given, surname, email, phone);
  }

  User? get _sessionUser {
    if (widget.forceSignedIn == false) return null;
    return _auth.currentUser;
  }

  bool get _isSignedIn =>
      _signedInOverride ?? widget.forceSignedIn ?? _sessionUser != null;

  List<String> get _documents => [
        for (final slot in MallDocumentSlot.all)
          if (_slotPaths[slot.kind] != null) _slotPaths[slot.kind]!,
      ];

  void _restoreDocuments(List<String> paths) {
    final unused = <String>[];
    for (final path in paths) {
      final kind = MallDocumentSlot.kindOf(path);
      if (kind != null && !_slotPaths.containsKey(kind)) {
        _slotPaths[kind] = path;
      } else {
        unused.add(path);
      }
    }
    for (final path in unused) {
      for (final slot in MallDocumentSlot.all) {
        if (_slotPaths.containsKey(slot.kind)) continue;
        _slotPaths[slot.kind] = path;
        break;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _legal,
      _tax,
      _taxOffice,
      _mersis,
      _registry,
      _kep,
      _phone,
      _website,
      _city,
      _district,
      _address,
      _person,
      _title,
      _floors,
      _givenName,
      _surname,
      _email,
      _accountPhone,
      _password,
      _confirm,
    ]) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  MallApplicationDraft get _draft => MallApplicationDraft(
        mallName: _name.text,
        legalName: _legal.text,
        taxNumber: _tax.text,
        taxOffice: _taxOffice.text,
        mersisNo: _mersis.text,
        tradeRegistryNo: _registry.text,
        kepAddress: _kep.text,
        city: _city.text,
        district: _district.text,
        addressText: _address.text,
        latitude: _latitude,
        longitude: _longitude,
        phone: _phone.text,
        website: MallApplicationValidation.normalizeWebsite(_website.text),
        logoUrl: _logoUrl,
        coverUrl: _coverUrl,
        authorizedPersonName: _accountName.isNotEmpty ? _accountName : _person.text,
        authorizedPersonTitle: _title.text,
        authorizedPersonPhone: _accountPhone.text,
        authorizedPersonEmail: _email.text,
        declaredFloorCount:
            MallApplicationValidation.parseDeclaredFloorCount(_floors.text),
        documentPaths: _documents,
      );

  String get _accountName =>
      '${_givenName.text.trim()} ${_surname.text.trim()}'.trim();

  String? _lastMissingLog;

  List<MallSubmitIssue> get _submitIssues {
    final issues = MallApplicationValidation.submitIssues(
      _draft,
      documentKinds: _slotPaths.keys,
      floorText: _floors.text,
    );
    final log = issues.map((issue) => issue.field).join(', ');
    if (log != _lastMissingLog) {
      _lastMissingLog = log;
      debugPrint('[MALL][SUBMIT_VALIDATION] missingFields=[$log]');
    }
    return issues;
  }

  bool get _canSubmit => _submitIssues.isEmpty;

  bool get _canSaveDraft =>
      widget.existing == null || widget.existing!.status.isEditable;

  FocusNode _node(String field) => _focusNodes.putIfAbsent(field, FocusNode.new);

  /// Shown once the field has text, the step was attempted, or the step is behind.
  String? _fieldError(String field, TextEditingController controller) {
    for (final issue in _submitIssues) {
      if (issue.field != field) continue;
      final visible = controller.text.trim().isNotEmpty ||
          _revealedSteps.contains(issue.step) ||
          issue.step < _step;
      return visible ? issue.message : null;
    }
    return null;
  }

  bool _validateStep(int step) {
    final issues = [
      for (final issue in _submitIssues)
        if (issue.step == step) issue,
    ];
    if (issues.isEmpty) return true;
    debugPrint(
      '[MALL][SUBMIT_VALIDATION] step=$step blocked fields=[${issues.map((i) => i.field).join(', ')}]',
    );
    setState(() {
      _revealedSteps.add(step);
      _errorStep = step;
      _error = step == 3 ? issues.first.message : null;
    });
    _focusNodes[issues.first.field]?.requestFocus();
    return false;
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? media,
    bool errorOnCurrentStep = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyMedia = media;
      _error = null;
      _errorStep = null;
    });
    try {
      await action();
    } catch (error) {
      debugPrint('[MALL][MEDIA] media=${media ?? 'form'} error=$error');
      if (mounted) {
        setState(() {
          _error = _uploadMessage(error, media: media);
          _errorStep = errorOnCurrentStep
              ? _step
              : MallApplicationValidation.stepForError(_error!);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMedia = null;
        });
      }
    }
  }

  String _uploadMessage(Object error, {String? media}) {
    if (error is MallApplicationException) return error.message;
    if (media == 'document') {
      return 'Belge yüklenemedi. Önce eksik başvuru bilgilerini tamamlayın.';
    }
    if (media == 'cover') {
      return 'Kapak görseli yüklenemedi. AVM medya alanına erişim sağlanamadı.';
    }
    if (media == 'logo') {
      return 'Logo yüklenemedi. AVM medya alanına erişim sağlanamadı.';
    }
    return 'İşlem tamamlanamadı. Lütfen bilgileri kontrol edin.';
  }

  /// Draft rules only (DB constraints). Never blocked by submit completeness.
  Future<void> _ensureDraft() async {
    final website = MallApplicationValidation.normalizeWebsite(_website.text);
    if (website != null && website != _website.text) _website.text = website;
    final draft = _draft;
    final errors =
        MallApplicationValidation.draftErrors(draft, floorText: _floors.text);
    if (errors.isNotEmpty) {
      debugPrint('[MALL][DRAFT_SAVE] blocked draftErrors=${errors.length}');
      throw MallApplicationException(
        'Taslak için zorunlu: ${errors.join(', ')}',
      );
    }
    if (_sessionUser == null && _signedInOverride != true) {
      throw MallApplicationException('Başvuru için önce hesap adımını tamamlayın');
    }
    if (_applicationId == null) {
      final mine = await widget.repository.getMyApplications();
      for (final item in mine) {
        if (!item.status.isEditable) continue;
        _applicationId = item.id;
        break;
      }
    }
    if (_applicationId == null) {
      debugPrint('[MALL][DRAFT_SAVE] mode=create applicationId=null');
      final created = await widget.repository.createDraft(draft);
      _applicationId = created.id;
    } else {
      debugPrint('[MALL][DRAFT_SAVE] mode=update applicationId=$_applicationId');
      await widget.repository.updateDraft(
        applicationId: _applicationId!,
        draft: draft,
      );
    }
  }

  Future<void> _saveDraft() async {
    if (!_canSaveDraft) return;
    await _run(errorOnCurrentStep: true, () async {
      await _ensureDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başvuru taslağı kaydedildi.')),
      );
    });
  }

  Future<void> _submit() async {
    await _run(errorOnCurrentStep: true, () async {
      final issues = _submitIssues;
      if (issues.isNotEmpty) {
        throw MallApplicationException(
          'Eksik bilgiler: ${issues.map((issue) => issue.field).join(', ')}',
        );
      }
      await _ensureDraft();
      debugPrint('[MALL][SUBMIT] rpc applicationId=$_applicationId');
      await widget.repository.submitApplication(_applicationId!);
      if (!mounted) return;
      widget.onFinished();
    });
  }

  Future<void> _continueAccount() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() {
        _error = 'Yetkili görevi zorunlu';
        _errorStep = 0;
      });
      return;
    }
    if (_isSignedIn) {
      final name = '${_givenName.text.trim()} ${_surname.text.trim()}'.trim();
      if (name.isEmpty) {
        setState(() {
          _error = 'Yetkili adı zorunlu';
          _errorStep = 0;
        });
        return;
      }
      _person.text = name;
      await _run(() async {
        final phone = _accountPhone.text.trim();
        await _auth.ensureUserRow(
          displayName: name,
          phone: phone.isEmpty ? null : phone,
        );
        if (!mounted) return;
        setState(() => _step = 1);
      });
      return;
    }
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _error = 'Geçerli bir e-posta girin.';
        _errorStep = 0;
      });
      return;
    }
    if (_existingAccount) {
      if (_password.text.isEmpty) {
        setState(() {
          _error = 'Şifre zorunlu';
          _errorStep = 0;
        });
        return;
      }
      await _run(() async {
        try {
          await _auth.signIn(email: email, password: _password.text);
        } catch (error) {
          throw MallApplicationException(MallAuthSession.describeError(error));
        }
        await _finishAuth(email);
      });
      return;
    }
    if (_givenName.text.trim().isEmpty || _surname.text.trim().isEmpty) {
      setState(() {
        _error = 'Ad ve soyad zorunlu';
        _errorStep = 0;
      });
      return;
    }
    if (_accountPhone.text.trim().isEmpty) {
      setState(() {
        _error = 'Telefon zorunlu';
        _errorStep = 0;
      });
      return;
    }
    if (_password.text.length < 6) {
      setState(() {
        _error = 'Şifre en az 6 karakter olmalıdır.';
        _errorStep = 0;
      });
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() {
        _error = 'Şifreler eşleşmiyor.';
        _errorStep = 0;
      });
      return;
    }
    await _run(() async {
      try {
        final response = await _auth.signUp(
          email: email,
          password: _password.text,
          displayName: '${_givenName.text.trim()} ${_surname.text.trim()}'.trim(),
          phone: _accountPhone.text.trim(),
        );
        final identities = response.user?.identities;
        final hasSession = response.session != null || _auth.currentUser != null;
        if (!hasSession && (identities == null || identities.isEmpty)) {
          if (!mounted) return;
          setState(() {
            _existingAccount = true;
            _error = null;
            _errorStep = 0;
          });
          return;
        }
        if (!hasSession) {
          throw MallApplicationException(
            'Hesap oluşturuldu. E-postayı doğruladıktan sonra aynı ekrandan giriş yapın.',
          );
        }
      } catch (error) {
        final raw = error.toString().toLowerCase();
        if (raw.contains('already') ||
            raw.contains('registered') ||
            raw.contains('email_exists')) {
          if (!mounted) return;
          setState(() {
            _existingAccount = true;
            _error = null;
            _errorStep = 0;
          });
          return;
        }
        rethrow;
      }
      await _finishAuth(email);
    });
  }

  Future<void> _finishAuth(String email) async {
    final name = '${_givenName.text.trim()} ${_surname.text.trim()}'.trim();
    _person.text = name;
    debugPrint('[MALL][APPLY] mall session uid=${_auth.currentUser?.id}');
    final phone = _accountPhone.text.trim();
    await _auth.ensureUserRow(
      displayName: name.isEmpty ? null : name,
      phone: phone.isEmpty ? null : phone,
    );
    _password.clear();
    _confirm.clear();
    if (!mounted) return;
    setState(() {
      _signedInOverride = true;
      _existingAccount = false;
      _email.text = email;
      _step = 1;
      _error = null;
    });
  }

  Future<void> _pickDocument(String kind) async {
    if (_busy) return;
    final picked = await _pickFile(
      tag: 'DOCUMENT',
      extensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (picked == null || !mounted) return;
    await _run(media: 'document', () async {
      await _ensureDraft();
      final applicationId = _applicationId;
      if (applicationId == null || applicationId.isEmpty) {
        throw MallApplicationException('Başvuru taslağı oluşturulamadı.');
      }
      if (!MallApplicationValidation.documentFileAllowed(
        fileName: picked.name,
        byteLength: picked.bytes.length,
      )) {
        throw MallApplicationException(
          'Belge PDF, JPG veya PNG olmalı ve 10 MB altında kalmalı',
        );
      }
      final previous = _slotPaths[kind];
      final path = await widget.repository.uploadDocument(
        applicationId: applicationId,
        fileName: picked.name,
        bytes: picked.bytes,
        kind: kind,
      );
      if (previous != null) {
        try {
          await widget.repository.removeDocument(previous);
        } catch (error) {
          debugPrint('[MALL][DOCUMENT] previous remove failed: $error');
        }
        _documentSizes.remove(previous);
      }
      _slotPaths[kind] = path;
      _documentSizes[path] = picked.bytes.length;
      try {
        await widget.repository.updateDraft(
          applicationId: applicationId,
          draft: _draft,
        );
      } catch (error) {
        debugPrint('[MALL][DOCUMENT] db update after upload failed: $error');
        if (error is MallApplicationException) rethrow;
        throw MallApplicationException(draftWriteMessage(error));
      }
      await widget.repository.recordDocument(
        applicationId: applicationId,
        kind: kind,
        path: path,
        fileName: picked.name,
        sizeBytes: picked.bytes.length,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belge yüklendi')),
      );
    });
  }

  Future<void> _removeDocument(String path) async {
    await _run(() async {
      await widget.repository.removeDocument(path);
      _slotPaths.removeWhere((_, value) => value == path);
      _documentSizes.remove(path);
      if (_applicationId != null) {
        await widget.repository.updateDraft(
          applicationId: _applicationId!,
          draft: _draft,
        );
      }
    });
  }

  Future<void> _openDocument(String path) async {
    await _run(() async {
      final url = await widget.repository.signedDocumentUrl(path);
      final launched = await launchUrl(Uri.parse(url));
      if (!launched) {
        throw MallApplicationException('Belge açılamadı');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1100;
    final form = _formCard();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: desktop ? 28 : 16,
            vertical: 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _resubmit ? 'Başvuruyu güncelle' : 'AVM\'nizi İBUL\'a Ekleyin',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'AVM yönetiminizi İBUL\'un dijital ekosistemine taşıyın. Başvurunuz güvenli şekilde incelenir.',
              ),
              const SizedBox(height: 20),
              if (desktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 65, child: form),
                    const SizedBox(width: 20),
                    Expanded(flex: 35, child: _summary()),
                  ],
                )
              else
                form,
            ],
          ),
        ),
      ),
    );
  }

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_resubmit && (widget.existing?.adminNote?.isNotEmpty ?? false)) ...[
            MallNoteCard(
              title: 'İBUL ekibi başvurunuz için ek bilgi istiyor.',
              body: widget.existing!.adminNote!,
            ),
            const SizedBox(height: 16),
          ],
          MallApplicationStepper(
            labels: _steps,
            index: _step,
            errorIndex: _errorStep,
            incompleteSteps: {for (final issue in _submitIssues) issue.step},
            onSelect: _busy
                ? null
                : (step) {
                    if (step <= _step) setState(() => _step = step);
                  },
          ),
          const SizedBox(height: 20),
          _stepBody(),
          if (_error != null &&
              (_errorStep == null ||
                  _errorStep == _step ||
                  _step == _steps.length - 1)) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          _actions(),
        ],
      ),
    );
  }

  Widget _summary() {
    final floors = MallApplicationValidation.parseDeclaredFloorCount(_floors.text);
    return MallApplicationSummary(
      name: _name.text,
      city: _city.text,
      district: _district.text,
      address: _address.text,
      floorLabel: floors == null ? null : '$floors Kat',
      logoBytes: _localLogoBytes,
      coverBytes: _localCoverBytes,
      logoUrl: _logoUrl,
      coverUrl: _coverUrl,
      ready: _canSubmit,
      missing: [for (final issue in _submitIssues) issue.field],
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return MallApplicationAccountStep(
          signedIn: _isSignedIn,
          existingAccount: _existingAccount,
          givenName: _givenName,
          surname: _surname,
          email: _email,
          phone: _accountPhone,
          title: _title,
          password: _password,
          confirm: _confirm,
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('İşletme Bilgileri', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _fields([
              _field(_legal, 'Şirket / ticari unvan *', issue: 'Şirket / ticari unvan'),
              _field(
                _tax,
                'Vergi numarası *',
                issue: 'Vergi numarası',
                keyboard: TextInputType.number,
                digitsMax: 11,
              ),
              _field(_taxOffice, 'Vergi dairesi *', issue: 'Vergi dairesi'),
              _field(
                _mersis,
                'MERSİS numarası *',
                issue: 'MERSİS numarası',
                keyboard: TextInputType.number,
                digitsMax: 16,
              ),
              _field(_registry, 'Ticaret sicil numarası *', issue: 'Ticaret sicil numarası'),
              _field(
                _kep,
                'KEP adresi',
                issue: 'KEP adresi',
                hint: 'ornek@hs01.kep.tr',
                keyboard: TextInputType.emailAddress,
              ),
            ]),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AVM Bilgileri', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Müşterilerin göreceği temel AVM bilgilerini girin.'),
            const SizedBox(height: 16),
            _fields([
              _field(_name, 'AVM adı *', issue: 'AVM adı'),
              _field(_phone, 'Telefon', issue: 'AVM telefonu'),
              _field(_website, 'Web sitesi', issue: 'Web sitesi', hint: 'primall.com'),
              _field(
                _floors,
                'Kat sayısı',
                issue: 'Kat sayısı',
                keyboard: TextInputType.number,
              ),
            ]),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AVM Konumu', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            MallLocationEditor(
              city: _city,
              district: _district,
              address: _address,
              latitude: _latitude,
              longitude: _longitude,
              onPoint: (lat, lng) => setState(() {
                _latitude = lat;
                _longitude = lng;
              }),
              onClearPoint: () => setState(() {
                _latitude = null;
                _longitude = null;
              }),
            ),
          ],
        );
      case 4:
        return _documentsStep();
      default:
        return _preview();
    }
  }

  Widget _documentsStep() {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final media = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _logoCard(),
              const SizedBox(width: 16),
              Expanded(child: _coverCard()),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _logoCard(),
              const SizedBox(height: 16),
              _coverCard(),
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        media,
        const SizedBox(height: 20),
        const Text(
          'AVM Yetki Doğrulama',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Kimlik ve ticari belgeler gizli alanda saklanır.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (final slot in MallDocumentSlot.all) ...[
          Text(slot.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (_slotPaths[slot.kind] == null)
            FilledButton.icon(
              onPressed: _busy ? null : () => _pickDocument(slot.kind),
              icon: const Icon(Icons.upload_file),
              label: Text(
                slot.kind == 'authority' ? 'Yetki Belgesi Yükle' : 'Yükle',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            )
          else
            _documentCard(_slotPaths[slot.kind]!, slot.label),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _logoCard() {
    final hasImage = _localLogoBytes != null || (_logoUrl?.isNotEmpty ?? false);
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AVM Logosu', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: AppColors.surfaceMuted,
              child: MallImageFrame(
                bytes: _localLogoBytes,
                url: _logoUrl,
                aspectRatio: 1,
                logTag: 'LOGO_PREVIEW',
                placeholder: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_outlined, color: AppColors.iconMuted),
                    SizedBox(height: 8),
                    Text('AVM logosu'),
                    Text('PNG, JPG veya WEBP', style: TextStyle(fontSize: 12)),
                    Text('Önerilen: 800×800', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _pickImage(logo: true),
                child: Text(
                  _busyMedia == 'logo'
                      ? 'Logo yükleniyor...'
                      : hasImage
                          ? 'Değiştir'
                          : 'Logo Yükle',
                ),
              ),
              if (hasImage)
                TextButton(
                  onPressed: _busy ? null : _removeLogo,
                  child: const Text('Kaldır'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coverCard() {
    final hasImage = _localCoverBytes != null || (_coverUrl?.isNotEmpty ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AVM Kapak Görseli', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('AVM sayfanızın üst bölümünde gösterilir. Önerilen: 1600×600'),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: AppColors.surfaceMuted,
            child: MallImageFrame(
              bytes: _localCoverBytes,
              url: _coverUrl,
              aspectRatio: 16 / 6,
              logTag: 'COVER_PREVIEW',
              placeholder: const Center(
                child: Icon(Icons.panorama_outlined, color: AppColors.iconMuted),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: _busy ? null : () => _pickImage(logo: false),
              child: Text(
                _busyMedia == 'cover'
                    ? 'Kapak yükleniyor...'
                    : hasImage
                        ? 'Değiştir'
                        : 'Kapak Yükle',
              ),
            ),
            if (hasImage)
              TextButton(
                onPressed: _busy ? null : _removeCover,
                child: const Text('Kaldır'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage({required bool logo}) async {
    if (_busy) return;
    final tag = logo ? 'LOGO' : 'COVER';
    final picked = await _pickFile(
      tag: tag,
      extensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (picked == null || !mounted) return;
    final sizeError = await _imageSizeError(picked.bytes, logo: logo);
    if (sizeError != null) {
      setState(() {
        _error = sizeError;
        _errorStep = 3;
      });
      return;
    }
    final cropped = await _cropImage(picked.bytes, logo: logo);
    if (cropped == null || !mounted) return;
    setState(() {
      if (logo) {
        _localLogoBytes = cropped;
      } else {
        _localCoverBytes = cropped;
      }
    });
    await _run(media: logo ? 'logo' : 'cover', () async {
      await _ensureDraft();
      final applicationId = _applicationId;
      if (applicationId == null || applicationId.isEmpty) {
        throw MallApplicationException('Başvuru taslağı oluşturulamadı.');
      }
      if (!MallApplicationValidation.imageFileAllowed(
        fileName: picked.name,
        byteLength: cropped.length,
      )) {
        throw MallApplicationException(
          'Logo ve kapak JPG, PNG veya WEBP olmalı ve 10 MB altında kalmalı',
        );
      }
      final url = logo
          ? await widget.repository.uploadLogo(
              applicationId: applicationId,
              fileName: picked.name,
              bytes: cropped,
              previousUrl: _logoUrl,
            )
          : await widget.repository.uploadCover(
              applicationId: applicationId,
              fileName: picked.name,
              bytes: cropped,
              previousUrl: _coverUrl,
            );
      if (logo) {
        _logoUrl = url;
      } else {
        _coverUrl = url;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(logo ? 'Logo yüklendi' : 'Kapak yüklendi')),
      );
    });
  }

  Future<Uint8List?> _cropImage(Uint8List bytes, {required bool logo}) {
    Uint8List? cropped;
    return showDialog<void>(
      context: context,
      builder: (context) => ImageCropperWidget(
        imageData: bytes,
        aspectRatio: logo ? 1 : 16 / 6,
        title: logo ? 'Logoyu kırpın' : 'Kapağı kırpın',
        helpText: logo
            ? 'Kare çerçeveyi yakınlaştırıp konumlandırın. Çıktı 1:1 olur.'
            : 'Kapak çerçevesini yakınlaştırıp konumlandırın. Çıktı 16:6 olur.',
        onCropped: (data) => cropped = data,
      ),
    ).then((_) => cropped);
  }

  Future<String?> _imageSizeError(Uint8List bytes, {required bool logo}) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final width = frame.image.width;
    final height = frame.image.height;
    frame.image.dispose();
    if (logo && (width < 400 || height < 400)) {
      return 'Logo en az 400 × 400 px olmalıdır.';
    }
    if (!logo && (width < 1200 || height < 450)) {
      return 'Kapak en az 1200 × 450 px olmalıdır.';
    }
    return null;
  }

  Future<({String name, Uint8List bytes})?> _pickFile({
    required String tag,
    required List<String> extensions,
  }) async {
    final picked = await FilePicker.platform.pickFiles(
      withData: mallPickerWithData,
      withReadStream: mallPickerWithReadStream,
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (picked == null || picked.files.isEmpty) {
      debugPrint('[MALL][$tag] picker cancelled');
      return null;
    }
    final file = picked.files.single;
    final bytes = await readMallPickedFile(file);
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        setState(() {
          _error = 'Dosya okunamadı. Lütfen farklı bir dosya seçin.';
          _errorStep = 4;
        });
      }
      return null;
    }
    return (name: file.name, bytes: bytes);
  }

  Future<void> _removeLogo() async {
    await _run(() async {
      if (_applicationId == null) return;
      await widget.repository.removeLogo(
        applicationId: _applicationId!,
        previousUrl: _logoUrl,
      );
      _logoUrl = null;
      _localLogoBytes = null;
    });
  }

  Future<void> _removeCover() async {
    await _run(() async {
      if (_applicationId == null) return;
      await widget.repository.removeCover(
        applicationId: _applicationId!,
        previousUrl: _coverUrl,
      );
      _coverUrl = null;
      _localCoverBytes = null;
    });
  }

  Widget _documentCard(String path, String title) {
    final name = path.split('/').last;
    final lower = name.toLowerCase();
    final isPdf = lower.endsWith('.pdf');
    final bytes = _documentSizes[path];
    final sizeLabel = bytes == null ? null : _formatBytes(bytes);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          [
            name,
            isPdf ? 'PDF' : 'Görsel belge',
            ?sizeLabel,
          ].join(' • '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _busy ? null : () => _openDocument(path),
              child: const Text('Görüntüle'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _removeDocument(path),
              child: const Text('Sil'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _preview() {
    final draft = _draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Önizleme', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _summary(),
        const SizedBox(height: 16),
        Text('Yetkili: ${draft.authorizedPersonName} · ${draft.authorizedPersonTitle}'),
        Text(
          'Belgeler: ${_slotPaths.length} / ${MallDocumentSlot.all.length}',
        ),
      ],
    );
  }

  Widget _actions() {
    final last = _step == _steps.length - 1;
    return Row(
      children: [
        if (_step > 0)
          OutlinedButton(
            onPressed: _busy ? null : () => setState(() => _step -= 1),
            child: const Text('Geri'),
          ),
        const Spacer(),
        if (_canSaveDraft && _isSignedIn)
          OutlinedButton(
            onPressed: _busy ? null : _saveDraft,
            child: const Text('Taslak Kaydet'),
          ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : last
                  ? (_canSubmit ? _submit : null)
                  : () {
                      if (_step == 0) {
                        _continueAccount();
                        return;
                      }
                      if (_step <= 3 && !_validateStep(_step)) return;
                      setState(() {
                        _step += 1;
                        _error = null;
                        _errorStep = null;
                      });
                    },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(
            last
                ? (_resubmit ? 'Tekrar Gönder' : 'Başvuruyu Gönder')
                : (_step == 0 && _existingAccount && !_isSignedIn)
                    ? 'Giriş Yap ve Devam Et'
                    : 'Devam Et',
          ),
        ),
      ],
    );
  }

  Widget _fields(List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboard,
    String? issue,
    String? hint,
    int? digitsMax,
  }) {
    return TextField(
      controller: controller,
      focusNode: issue == null ? null : _node(issue),
      maxLines: maxLines,
      keyboardType: keyboard,
      inputFormatters: digitsMax == null
          ? null
          : [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(digitsMax),
            ],
      onChanged: (value) {
        logMallFormInput(label, value);
        setState(() {});
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: issue == null ? null : _fieldError(issue, controller),
        errorMaxLines: 2,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

