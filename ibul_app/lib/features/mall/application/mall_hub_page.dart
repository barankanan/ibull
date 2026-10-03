import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/ibul_router.dart';
import '../../../app/marketplace_paths.dart';
import '../../../core/constants.dart';
import '../../../widgets/web_header.dart';
import '../../../widgets/web_sticky_footer_scroll_view.dart';
import '../auth/mall_auth_session.dart';
import '../management/models/mall_profile.dart';
import '../management/services/mall_management_repository.dart';
import '../models/mall_application.dart';
import '../services/mall_application_repository.dart';

String mallHubApplyRoute() => MarketplacePaths.mallApplication;

String mallHubSignInRoute() => MarketplacePaths.mallLogin;

const mallNoLinkedMallNotice = 'Bu AVM yönetici hesabına bağlı bir AVM bulunamadı.';

String mallHubNoApplicationRoute() => '${MarketplacePaths.mallHub}?basvuru=yok';

/// [loggedIn] is the AVM session, never the marketplace customer session.
/// null means the AVM account has neither a membership nor an application.
String? mallHubEntryTarget({
  required bool loggedIn,
  required bool hasMembership,
  required bool hasApplication,
  String? managementPath,
}) {
  if (!loggedIn) return mallHubSignInRoute();
  if (hasMembership) return managementPath ?? MarketplacePaths.mallManagement;
  if (hasApplication) return MarketplacePaths.mallApplication;
  return null;
}

class MallHubPage extends StatefulWidget {
  const MallHubPage({
    super.key,
    this.session,
    this.managementRepository,
    this.applicationRepository,
  });

  final MallAuthSession? session;
  final MallManagementRepository? managementRepository;
  final MallApplicationRepository? applicationRepository;

  @override
  State<MallHubPage> createState() => _MallHubPageState();
}

class _MallHubPageState extends State<MallHubPage> {
  var _loading = true;
  String? _error;
  String? _entryNotice;
  List<MallMembership> _memberships = [];
  List<MallApplication> _applications = [];

  MallAuthSession get _session => widget.session ?? MallAuthSession.instance;

  bool get _loggedIn => _session.isSignedIn;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _session.restore();
    if (!mounted) return;
    if (!_loggedIn) {
      setState(() {
        _memberships = [];
        _applications = [];
        _loading = false;
      });
      return;
    }
    var memberships = const <MallMembership>[];
    var applications = const <MallApplication>[];
    Object? failure;
    try {
      memberships = await (widget.managementRepository ?? MallManagementRepository()).myMemberships();
    } catch (error) {
      debugPrint('[MALL][LOGIN] hub membership lookup failed: $error');
      failure = error;
    }
    try {
      applications = await (widget.applicationRepository ?? MallApplicationRepository()).getMyApplications();
    } catch (error) {
      debugPrint('[MALL][LOGIN] hub application lookup failed: $error');
      failure = error;
    }
    if (!mounted) return;
    setState(() {
      _memberships = memberships;
      _applications = applications;
      _error = failure != null && memberships.isEmpty && applications.isEmpty
          ? friendlyMallError(failure)
          : null;
      _loading = false;
    });
  }

  bool get _arrivedWithoutApplication {
    try {
      return GoRouterState.of(context).uri.queryParameters['basvuru'] == 'yok';
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MarketplaceWebPageShell(
      backgroundColor: const Color(0xFFF7F7F9),
      header: WebHeader(onSearch: (_) {}),
      child: _loading
          ? const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: _panel(),
                ),
              ),
            ),
    );
  }

  Widget _panel() {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final story = const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AVM\'nizi İBUL\'a Ekleyin',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 12),
        Text(
          'AVM\'nizi mağaza rehberine, kat bilgilerine ve yönetim araçlarına eklemek için başvurun.',
        ),
        SizedBox(height: 16),
        Text('• Mağaza rehberi'),
        Text('• Kat ve birim bilgileri'),
        Text('• Doğrulanmış başvuru'),
        SizedBox(height: 12),
        Text('Başvurunuz İBUL ekibi tarafından incelenir.'),
      ],
    );
    final card = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('AVM İşlemleri', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_statusLine != null) ...[
            Text(_statusLine!, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
          ],
          if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.danger)),
          if (_notice != null) ...[
            Text(_notice!, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
          ],
          ..._actions(),
          if (_loggedIn) ...[
            const SizedBox(height: 16),
            Text(
              'AVM hesabı: ${_session.currentUser?.email ?? ''}',
              key: const Key('mall-hub-account'),
              style: const TextStyle(color: AppColors.textGrey),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('mall-hub-signout'),
                onPressed: _signOut,
                child: const Text('AVM oturumunu kapat'),
              ),
            ),
          ],
        ],
      ),
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [story, const SizedBox(height: 24), card],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: story),
        const SizedBox(width: 28),
        SizedBox(width: 420, child: card),
      ],
    );
  }

  String? get _notice {
    if (_entryNotice != null) return _entryNotice;
    if (_loggedIn &&
        _memberships.isEmpty &&
        _applications.isEmpty &&
        _arrivedWithoutApplication) {
      return mallNoLinkedMallNotice;
    }
    return null;
  }

  Future<void> _signOut() async {
    await _session.signOut();
    if (!mounted) return;
    setState(() => _entryNotice = null);
    await _load();
  }

  String? get _statusLine {
    if (!_loggedIn || _memberships.isNotEmpty) return null;
    if (_applications.any((item) => item.status == MallApplicationStatus.needsInfo)) {
      return 'Ek bilgi gerekiyor';
    }
    if (_applications.any((item) => item.status == MallApplicationStatus.pendingReview)) {
      return 'Başvurunuz inceleniyor';
    }
    return null;
  }

  void _openEntry() {
    final managementPath = _memberships.isEmpty
        ? null
        : _memberships.length == 1
            ? MarketplacePaths.mallManagementMall(_memberships.first.mallId)
            : MarketplacePaths.mallManagement;
    final target = mallHubEntryTarget(
      loggedIn: _loggedIn,
      hasMembership: _memberships.isNotEmpty,
      hasApplication: _applications.isNotEmpty,
      managementPath: managementPath,
    );
    if (target == null) {
      setState(() {
        _entryNotice = mallNoLinkedMallNotice;
      });
      return;
    }
    debugPrint('[MALL][LOGIN] hub entry target=$target');
    IbulRouter.go(context, target);
  }

  List<Widget> _actions() {
    final buttons = <Widget>[
      FilledButton(
        onPressed: () => IbulRouter.go(context, mallHubApplyRoute()),
        child: const Text('AVM Başvurusu Yap'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: _openEntry,
        child: const Text('AVM Girişi'),
      ),
    ];
    return buttons;
  }
}
