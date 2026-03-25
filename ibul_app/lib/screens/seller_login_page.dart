import 'package:flutter/material.dart';
import '../core/app_motion.dart';
import '../core/constants.dart';
import 'become_seller_page.dart';
import '../services/auth_service.dart';
import 'seller/admin_panel_page.dart';

class SellerLoginPage extends StatefulWidget {
  const SellerLoginPage({super.key, this.adminMode = false});

  final bool adminMode;

  @override
  State<SellerLoginPage> createState() => _SellerLoginPageState();
}

class _SellerLoginPageState extends State<SellerLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
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

        // 2. Check User Role and Status
        // Add a small delay to ensure Firestore data is propagated if it was just created (rare case but good safety)
        await Future.delayed(const Duration(milliseconds: 500));

        final role = await _authService.getUserDataField('role');
        // Check both camelCase and snake_case just in case, but DB uses snake_case
        final isSellerApproved = await _authService.getUserDataField(
          'is_seller_approved',
        );

        if (!mounted) return;

        if (widget.adminMode) {
          if (AuthService.isAdminRole(role?.toString())) {
            Navigator.pushReplacement(
              context,
              buildAppPageRoute<void>(
                builder: (context) => const AdminPanelPage(),
              ),
            );
            return;
          }

          await _authService.signOut();
          throw Exception('Bu hesap admin degil. Rol: $role');
        }

        if (role == 'seller') {
          if (isSellerApproved == true) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/seller', (route) => false);
            return;
          } else {
            // Not approved yet
            await _authService.signOut(); // Logout
            throw Exception(
              'Satıcı hesabınız henüz onaylanmadı. Lütfen yönetici onayını bekleyin.',
            );
          }
        } else {
          // Not a seller
          await _authService.signOut();
          throw Exception(
            'Bu e-posta adresi bir satıcı hesabına ait değil. Rol: $role',
          );
        }
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
    final pageTitle = widget.adminMode ? 'Admin Girişi' : 'Satıcı Girişi';
    final panelTitle = widget.adminMode
        ? 'Admin Paneline Giriş'
        : 'Satıcı Paneline Giriş';
    final subtitle = widget.adminMode
        ? 'Admin yetkileriyle devam etmek için giriş yapın.'
        : 'Mağazanızı yönetmek için giriş yapın.';
    final icon = widget.adminMode
        ? Icons.admin_panel_settings_outlined
        : Icons.store_mall_directory;
    final emailHint = widget.adminMode ? 'admin@ibul.com' : 'magaza@ornek.com';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          pageTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      // Logo veya İkon
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 50, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        panelTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Email / Phone Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'E-posta',
                          hintText: emailHint,
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: Colors.grey,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Lütfen e-posta adresinizi girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          hintText: '********',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Colors.grey,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Lütfen şifrenizi girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Login Button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            shadowColor: AppColors.primary.withOpacity(0.4),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'GİRİŞ YAP',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),

                      if (!widget.adminMode) ...[
                        const SizedBox(height: 16),

                        SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const BecomeSellerPage(),
                                      ),
                                    );
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: Colors.white,
                              elevation: 0,
                            ),
                            child: const Text(
                              'SATICI OL / BAŞVUR',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
