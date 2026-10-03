import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/ibul_router.dart';
import '../../../app/marketplace_paths.dart';
import '../../../core/constants.dart';
import '../auth/mall_auth_session.dart';
import '../management/models/mall_profile.dart';
import '../management/services/mall_management_repository.dart';
import '../services/mall_application_repository.dart';
import 'mall_hub_page.dart';

void mallGoBack(BuildContext context) {
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
    return;
  }
  IbulRouter.go(context, MarketplacePaths.mallHub);
}

/// Active membership wins, then any application. null: the AVM account has
/// neither, so the login page shows [mallNoLinkedMallNotice].
String? mallDestinationAfterLogin({
  required bool hasActiveMembership,
  required bool hasApplication,
  String? managementPath,
}) {
  return mallHubEntryTarget(
    loggedIn: true,
    hasMembership: hasActiveMembership,
    hasApplication: hasApplication,
    managementPath: managementPath,
  );
}

class MallAuthPage extends StatefulWidget {
  const MallAuthPage({
    super.key,
    this.register = false,
    this.session,
    this.managementRepository,
    this.applicationRepository,
  });

  /// Kept so older route calls compile. AVM register lives in the application wizard.
  final bool register;
  final MallAuthSession? session;
  final MallManagementRepository? managementRepository;
  final MallApplicationRepository? applicationRepository;

  @override
  State<MallAuthPage> createState() => _MallAuthPageState();
}

class _MallAuthPageState extends State<MallAuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  var _obscure = true;
  String? _error;

  MallAuthSession get _session => widget.session ?? MallAuthSession.instance;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Geçerli bir e-posta girin.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Şifre en az 6 karakter olmalıdır.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await _session.signIn(email: email, password: password);
      debugPrint('[MALL][LOGIN] mall session uid=${user?.id}');
      if (!mounted) return;
      final destination = await _destination();
      if (!mounted) return;
      if (destination == null) {
        setState(() => _error = mallNoLinkedMallNotice);
        return;
      }
      IbulRouter.go(context, destination);
    } catch (error) {
      debugPrint('[MALL][LOGIN] failed ${_errorCode(error)}');
      if (!mounted) return;
      setState(() => _error = MallAuthSession.describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorCode(Object error) {
    if (error is AuthException) {
      return 'type=AuthException status=${error.statusCode} code=${error.code} '
          'message=${error.message}';
    }
    return 'type=${error.runtimeType}';
  }

  Future<String?> _destination() async {
    var memberships = const <MallMembership>[];
    try {
      memberships = await (widget.managementRepository ?? MallManagementRepository()).myMemberships();
    } catch (error) {
      debugPrint('[MALL][LOGIN] membership lookup failed: $error');
    }
    var hasApplication = false;
    if (memberships.isEmpty) {
      try {
        hasApplication =
            (await (widget.applicationRepository ?? MallApplicationRepository()).getMyApplications())
                .isNotEmpty;
      } catch (error) {
        debugPrint('[MALL][LOGIN] application lookup failed: $error');
        hasApplication = true;
      }
    }
    final destination = mallDestinationAfterLogin(
      hasActiveMembership: memberships.isNotEmpty,
      hasApplication: hasApplication,
      managementPath: memberships.length == 1
          ? MarketplacePaths.mallManagementMall(memberships.first.mallId)
          : null,
    );
    debugPrint(
      '[MALL][LOGIN] uid=${_session.currentUser?.id} memberships=${memberships.length} '
      'application=$hasApplication destination=$destination',
    );
    return destination;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => IbulRouter.go(context, MarketplacePaths.mallHub),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('AVM İşlemleri'),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'AVM Yönetici Girişi',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('mall-login-email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'E-posta'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('mall-login-password'),
                        controller: _password,
                        obscureText: _obscure,
                        onSubmitted: (_) => _busy ? null : _submit(),
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: AppColors.danger)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('mall-login-submit'),
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('AVM Girişi Yap'),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Bu giriş yalnızca AVM yönetim hesabınız içindir.',
                        style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
