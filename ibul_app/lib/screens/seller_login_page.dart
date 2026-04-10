import 'package:flutter/material.dart';
import '../core/app_motion.dart';
import '../core/constants.dart';
import 'become_seller_page.dart';
import '../services/auth_service.dart';
import 'seller/admin_panel_page.dart';
import 'seller_panel_page.dart';

class SellerLoginPage extends StatefulWidget {
  const SellerLoginPage({super.key, this.adminMode = false});

  final bool adminMode;

  @override
  State<SellerLoginPage> createState() => _SellerLoginPageState();
}

class _SellerLoginPageState extends State<SellerLoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool _loginPressed = false;
  bool _sellerPressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final hadExistingUserSession = _authService.currentUser != null;

      try {
        if (hadExistingUserSession) {
          await _authService.backupCurrentSessionForSellerSwitch();
        } else {
          await _authService.clearSellerSwitchBackup();
        }

        // 1. Sign in
        await _authService.signInWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
          authArea: widget.adminMode ? 'admin' : 'seller',
        );

        final resolution = await _authService.resolveLoginRoute(
          diagnosticContext: widget.adminMode ? 'admin_login' : 'seller_login',
          includeStoreProfile: !widget.adminMode,
        );

        if (!mounted) return;

        if (widget.adminMode) {
          if (resolution.resolvedRole == LoginResolvedRole.admin) {
            Navigator.pushReplacement(
              context,
              buildAppPageRoute<void>(
                builder: (context) => const AdminPanelPage(),
              ),
            );
            return;
          }

          await _authService.signOut();
          throw Exception(
            'Bu hesap admin degil. Rol: ${resolution.rawRole ?? 'unknown'}',
          );
        }

        if (resolution.resolvedRole == LoginResolvedRole.seller) {
          if (resolution.isSellerApproved) {
            Navigator.of(
              context,
              rootNavigator: true,
            ).pushNamedAndRemoveUntil('/seller', (route) => false);
            return;
          } else {
            // Not approved yet
            await _authService.signOut(); // Logout
            throw Exception(
              'Satıcı hesabınız henüz onaylanmadı. Lütfen yönetici onayını bekleyin.',
            );
          }
        }

        if (resolution.resolvedRole == LoginResolvedRole.waiter) {
          Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
            '/seller',
            (route) => false,
            arguments: SellerPanelEntryRole.waiter,
          );
          return;
        }

        await _authService.signOut();
        throw Exception(
          'Bu e-posta adresi seller/garson hesabına ait değil. Rol: ${resolution.rawRole ?? 'unknown'}',
        );
      } catch (e) {
        if (hadExistingUserSession) {
          try {
            await _authService.restoreUserSessionAfterSellerExit();
          } catch (_) {
            await _authService.clearSellerSwitchBackup();
          }
        } else {
          await _authService.clearSellerSwitchBackup();
        }
        if (!mounted) return;
        final message = _authService.describeSignInError(
          e,
          adminMode: widget.adminMode,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Giriş başarısız: $message'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactMobile = screenWidth < 390;
    final hPad = isCompactMobile ? 20.0 : 24.0;

    // ── seller-specific strings ──────────────────────────────
    final panelTitle = widget.adminMode
        ? 'Admin Paneline Giriş'
        : 'Satıcı Paneline Giriş';
    final subtitle = widget.adminMode
        ? 'Admin yetkileriyle devam etmek için giriş yapın.'
        : 'Mağazanızı yönetmek için giriş yapın.';
    final heroIcon = widget.adminMode
        ? Icons.admin_panel_settings_outlined
        : Icons.store_mall_directory_outlined;
    final emailHint = widget.adminMode ? 'admin@ibul.com' : 'magaza@ornek.com';

    // ── colour tokens ─────────────────────────────────────────
    const primary = AppColors.primary;
    final primaryLight = primary.withValues(alpha: 0.10);
    final purpleBorder = primary.withValues(alpha: 0.25);
    const textDark = Color(0xFF111827);
    const textMid = Color(0xFF6B7280);
    const grey200 = Color(0xFFE5E7EB);

    // ── field decoration factory ───────────────────────────────────
    InputDecoration fieldDeco({
      required String label,
      required String hint,
      required Widget prefix,
      Widget? suffix,
    }) => InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 13, color: textMid),
      hintStyle: TextStyle(
        fontSize: 13,
        color: textMid.withValues(alpha: 0.55),
      ),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: purpleBorder, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOP NAV ROW ─────────────────────────────────
            Padding(
              padding: EdgeInsets.only(left: hPad - 8, top: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.maybePop(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: textDark.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
            // ── SCROLLABLE CONTENT ───────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: hPad,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── HERO ───────────────────────────────────
                              Center(
                                child: Container(
                                  width: isCompactMobile ? 76 : 84,
                                  height: isCompactMobile ? 76 : 84,
                                  decoration: BoxDecoration(
                                    color: primaryLight,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: primary.withValues(alpha: 0.12),
                                        blurRadius: 20,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    heroIcon,
                                    size: isCompactMobile ? 36 : 40,
                                    color: primary,
                                  ),
                                ),
                              ),

                              SizedBox(height: isCompactMobile ? 18 : 20),

                              // ── TITLE ───────────────────────────────────
                              Text(
                                panelTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isCompactMobile ? 20 : 22,
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                  letterSpacing: -0.3,
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text(
                                subtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isCompactMobile ? 13 : 14,
                                  color: textMid.withValues(alpha: 0.75),
                                  height: 1.4,
                                ),
                              ),

                              SizedBox(height: isCompactMobile ? 28 : 32),

                              // ── EMAIL ───────────────────────────────────
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                enableSuggestions: false,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: textDark,
                                ),
                                decoration: fieldDeco(
                                  label: 'E-posta',
                                  hint: emailHint,
                                  prefix: const Icon(
                                    Icons.email_outlined,
                                    size: 18,
                                    color: textMid,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Lütfen e-posta adresinizi girin';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 12),

                              // ── PASSWORD ───────────────────────────────────
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autocorrect: false,
                                enableSuggestions: false,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: textDark,
                                ),
                                decoration: fieldDeco(
                                  label: 'Şifre',
                                  hint: '••••••••',
                                  prefix: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 18,
                                    color: textMid,
                                  ),
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 18,
                                      color: textMid,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Lütfen şifrenizi girin';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: isCompactMobile ? 20 : 24),

                              // ── PRIMARY ACTIONS ────────────────────────────
                              if (widget.adminMode)
                                // Admin: single full-width gradient button
                                GestureDetector(
                                  onTapDown: (_) =>
                                      setState(() => _loginPressed = true),
                                  onTapUp: (_) =>
                                      setState(() => _loginPressed = false),
                                  onTapCancel: () =>
                                      setState(() => _loginPressed = false),
                                  onTap: _isLoading ? null : _handleLogin,
                                  child: AnimatedScale(
                                    scale: _loginPressed ? 0.97 : 1.0,
                                    duration: const Duration(milliseconds: 80),
                                    child: Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF8B3FF5),
                                            Color(0xFF6A1FD8),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primary.withValues(
                                              alpha: 0.28,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'Giriş Yap',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                    ),
                                  ),
                                )
                              else
                                // Seller: two-column row
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTapDown: (_) => setState(
                                          () => _loginPressed = true,
                                        ),
                                        onTapUp: (_) => setState(
                                          () => _loginPressed = false,
                                        ),
                                        onTapCancel: () => setState(
                                          () => _loginPressed = false,
                                        ),
                                        onTap: _isLoading ? null : _handleLogin,
                                        child: AnimatedScale(
                                          scale: _loginPressed ? 0.97 : 1.0,
                                          duration: const Duration(
                                            milliseconds: 80,
                                          ),
                                          child: Container(
                                            height: 44,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF8B3FF5),
                                                  Color(0xFF6A1FD8),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: primary.withValues(
                                                    alpha: 0.28,
                                                  ),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            alignment: Alignment.center,
                                            child: _isLoading
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : const Text(
                                                    'Giriş Yap',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GestureDetector(
                                        onTapDown: (_) => setState(
                                          () => _sellerPressed = true,
                                        ),
                                        onTapUp: (_) => setState(
                                          () => _sellerPressed = false,
                                        ),
                                        onTapCancel: () => setState(
                                          () => _sellerPressed = false,
                                        ),
                                        onTap: _isLoading
                                            ? null
                                            : () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const BecomeSellerPage(),
                                                ),
                                              ),
                                        child: AnimatedScale(
                                          scale: _sellerPressed ? 0.97 : 1.0,
                                          duration: const Duration(
                                            milliseconds: 80,
                                          ),
                                          child: Container(
                                            height: 44,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: primary,
                                                width: 1.5,
                                              ),
                                              color: Colors.white,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'Satıcı Ol',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: primary,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                              // ── DIVIDER (seller only) ────────────────────────
                              if (!widget.adminMode) ...[
                                SizedBox(height: isCompactMobile ? 20 : 24),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Divider(
                                        color: grey200,
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      child: Text(
                                        'satıcı başvurusu',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: textMid.withValues(
                                            alpha: 0.55,
                                          ),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                      child: Divider(
                                        color: grey200,
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isCompactMobile ? 16 : 20),
                                Center(
                                  child: Text(
                                    'Satıcı olmak için "Satıcı Ol" butonuna tıklayın.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textMid.withValues(alpha: 0.6),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
