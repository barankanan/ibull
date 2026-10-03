import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/ibul_router.dart';
import '../../../app/marketplace_paths.dart';
import '../../../core/constants.dart';
import '../../../widgets/web_header.dart';
import '../../../widgets/web_sticky_footer_scroll_view.dart';
import '../auth/mall_auth_session.dart';
import '../models/mall_application.dart';
import '../services/mall_application_repository.dart';
import '../widgets/mall_application_form.dart';

class MallApplicationPage extends StatefulWidget {
  const MallApplicationPage({super.key, this.repository, this.session});

  final MallApplicationRepository? repository;
  final MallAuthSession? session;

  @override
  State<MallApplicationPage> createState() => _MallApplicationPageState();
}

class _MallApplicationPageState extends State<MallApplicationPage> {
  late final MallApplicationRepository _repository =
      widget.repository ?? MallApplicationRepository();

  bool _loading = true;
  String? _error;
  List<MallApplication> _items = [];
  bool _editing = false;
  bool _startingNew = false;

  MallAuthSession get _session => widget.session ?? MallAuthSession.instance;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _session.restore();
    if (!mounted) return;
    if (!_sessionReady()) {
      setState(() {
        _loading = false;
        _editing = true;
      });
      return;
    }
    await _load();
  }

  bool _sessionReady() => _session.isSignedIn;

  Future<void> _load() async {
    if (!_sessionReady()) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _items = [];
        _editing = false;
        _startingNew = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _editing = false;
      _startingNew = false;
    });
    try {
      final items = await _repository.getMyApplications();
      if (!mounted) return;
      final primary = pickPrimaryMallApplication(items);
      setState(() {
        _items = items;
        _editing = primary == null || primary.status.isEditable;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  MallApplication? get _primary =>
      _startingNew ? null : pickPrimaryMallApplication(_items);

  void _startApplication() {
    setState(() {
      _startingNew = true;
      _editing = true;
    });
  }

  bool get _preferSignIn {
    try {
      return GoRouterState.of(context).uri.queryParameters['giris'] == '1';
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MarketplaceWebPageShell(
      header: WebHeader(onSearch: (_) {}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => IbulRouter.go(context, MarketplacePaths.mallHub),
              icon: const Icon(Icons.arrow_back),
              label: const Text('AVM İşlemleri'),
            ),
          ),
          _body(),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty && !_editing) {
      return _message(
        _error!,
        action: FilledButton(
          onPressed: _load,
          child: const Text('Tekrar dene'),
        ),
      );
    }
    final primary = _primary;
    if (_editing) {
      return MallApplicationWizard(
        repository: _repository,
        existing: _startingNew ? null : primary,
        session: _session,
        preferSignIn: _preferSignIn && !_sessionReady(),
        onFinished: _load,
      );
    }
    return MallApplicationHome(
      application: primary,
      onStart: _startApplication,
      onContinue: primary != null && primary.status.isEditable
          ? () => setState(() => _editing = true)
          : null,
      onCancelDraft: primary?.status == MallApplicationStatus.draft
          ? () => _cancel(primary!)
          : null,
    );
  }

  Future<void> _cancel(MallApplication application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Başvuruyu iptal et'),
        content: const Text('Taslak başvuru iptal edilsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('İptal et'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.cancelApplication(application.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Widget _message(String text, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}

class MallApplicationHome extends StatelessWidget {
  const MallApplicationHome({
    super.key,
    required this.application,
    required this.onStart,
    this.onContinue,
    this.onCancelDraft,
  });

  final MallApplication? application;
  final VoidCallback onStart;
  final VoidCallback? onContinue;
  final VoidCallback? onCancelDraft;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final application = this.application;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 32 : 16,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            if (application == null) ...[
              const Text(
                'AVM\'nizi İBUL\'a Ekleyin',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'AVM\'nizi İBUL haritasına, mağaza rehberine ve gelecekteki AVM yönetim araçlarına eklemek için başvurun.',
              ),
              const SizedBox(height: 16),
              const Text('✓ AVM mağaza rehberi'),
              const Text('✓ Kat bilgileri'),
              const Text('✓ İç mekan haritası'),
              const Text('✓ Kampanyalar'),
              const Text('✓ Reklam araçları'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Başvuru Başlat'),
              ),
            ] else
              _statusCard(context, application),
          ],
        ),
      ),
    ),
    );
  }

  Widget _statusCard(BuildContext context, MallApplication application) {
    final submitted = application.submittedAt ?? application.createdAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              application.status.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _title(application),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(application.mallName),
            if (submitted != null)
              Text('Başvuru tarihi: ${_format(submitted)}'),
            const SizedBox(height: 12),
            Text(_body(application)),
            if (application.status == MallApplicationStatus.rejected &&
                (application.rejectionReason?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              Text(application.rejectionReason!),
            ],
            const SizedBox(height: 16),
            if (application.status == MallApplicationStatus.approved)
              FilledButton(
                onPressed: () => IbulRouter.go(
                  context,
                  (application.createdMallId?.isNotEmpty ?? false)
                      ? MarketplacePaths.mallManagementMall(
                          application.createdMallId!,
                        )
                      : MarketplacePaths.mallManagement,
                ),
                child: const Text('AVM Yönetimine Git'),
              ),
            if (onContinue != null)
              FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  application.status == MallApplicationStatus.needsInfo
                      ? 'Düzelt ve gönder'
                      : 'Devam et',
                ),
              ),
            if (application.status == MallApplicationStatus.rejected ||
                application.status == MallApplicationStatus.cancelled)
              FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Yeni başvuru başlat'),
              ),
            if (onCancelDraft != null)
              TextButton(
                onPressed: onCancelDraft,
                child: const Text('Başvuruyu İptal Et'),
              ),
          ],
        ),
      ),
    );
  }

  String _title(MallApplication application) {
    return switch (application.status) {
      MallApplicationStatus.pendingReview => 'Başvurunuz inceleniyor.',
      MallApplicationStatus.approved => 'AVM başvurunuz onaylandı.',
      MallApplicationStatus.rejected => 'Başvuru reddedildi',
      MallApplicationStatus.cancelled => 'Başvuru iptal edildi.',
      MallApplicationStatus.needsInfo => 'Ek bilgi gerekli',
      MallApplicationStatus.draft => 'Taslak başvurunuz var',
      MallApplicationStatus.unknown => 'Başvuru durumu okunamadı',
    };
  }

  String _body(MallApplication application) {
    return switch (application.status) {
      MallApplicationStatus.pendingReview =>
        'Kısa süre içinde İBUL ekibi tarafından incelenecek.',
      MallApplicationStatus.approved =>
        'AVM hesabınız oluşturuldu. Kurulum adımlarını tamamladıktan sonra yayınlayabilirsiniz. AVM yönetim paneli hazırlanıyor.',
      MallApplicationStatus.rejected =>
        'Bu başvuru üzerinde düzenleme yapılamaz. Yeni bir başvuru başlatabilirsiniz.',
      MallApplicationStatus.cancelled =>
        'İptal edilen başvuruya dönülmez. Yeni bir başvuru başlatabilirsiniz.',
      _ => application.mallName,
    };
  }

  String _format(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
