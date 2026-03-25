import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/app_motion.dart';
import '../core/auth/user_identity.dart';
import '../core/config/app_feature_flags.dart';
import '../core/constants.dart';
import 'register_page.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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

      try {
        await _authService.signInWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
          authArea: 'user',
        );

        // Check User Role and Status
        final role = await _authService.getUserDataField('role');
        final isSellerApproved = await _authService.getUserDataField(
          'is_seller_approved',
        );

        if (!mounted) return;

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
        }

        // Login successful (Regular User)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Giriş başarılı!'),
            backgroundColor: Colors.green,
          ),
        );

        final appState = Provider.of<AppState>(context, listen: false);
        for (int i = 0; i < 20; i++) {
          if (!mounted) return;
          if (appState.isLoggedIn) break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          buildAppPageRoute<void>(
            builder: (context) => const HomeScreen(initialIndex: 4),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        final message = _authService.describeSignInError(e);
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
    final isMobile = screenWidth < 600;
    final isCompactMobile = screenWidth < 390;
    final contentMaxWidth = isMobile ? 420.0 : 450.0;
    final pagePadding = isCompactMobile ? 20.0 : 24.0;
    final topSpacing = isCompactMobile ? 8.0 : 16.0;
    final heroSize = isCompactMobile ? 82.0 : 92.0;
    final heroIconSize = isCompactMobile ? 38.0 : 44.0;
    final titleSize = isCompactMobile ? 22.0 : 24.0;
    final subtitleSize = isCompactMobile ? 13.0 : 14.0;
    final sectionSpacing = isCompactMobile ? 28.0 : 32.0;
    final buttonHeight = isCompactMobile ? 48.0 : 52.0;
    final buttonRadius = isCompactMobile ? 14.0 : 16.0;
    final primaryButtonFontSize = isCompactMobile ? 14.0 : 15.0;
    final secondaryButtonFontSize = isCompactMobile ? 13.5 : 14.5;
    final tertiaryButtonFontSize = isCompactMobile ? 14.0 : 15.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Giriş Yap',
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
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: Padding(
                padding: EdgeInsets.all(pagePadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: topSpacing),
                      // Logo veya İkon
                      Center(
                        child: Container(
                          width: heroSize,
                          height: heroSize,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            size: heroIconSize,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: isCompactMobile ? 20 : 22),
                      Text(
                        'İbul\'a Hoş Geldiniz',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Alışverişin en akıllı yolu. Devam etmek için giriş yapın.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: subtitleSize,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: sectionSpacing),

                      // Email / Phone Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'E-posta veya Telefon Numarası',
                          hintText: 'Örn: ornek@email.com veya 5551234567',
                          prefixIcon: const Icon(
                            Icons.person_outline,
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
                            return 'Lütfen e-posta veya telefon girin';
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
                      SizedBox(height: isCompactMobile ? 24 : 28),

                      // Login Button
                      SizedBox(
                        height: buttonHeight,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(buttonRadius),
                            ),
                            elevation: 2,
                            shadowColor: AppColors.primary.withValues(
                              alpha: 0.4,
                            ),
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
                              : Text(
                                  'GİRİŞ YAP',
                                  style: TextStyle(
                                    fontSize: primaryButtonFontSize,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Register Button
                      SizedBox(
                        height: buttonHeight,
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterPage(),
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
                              borderRadius: BorderRadius.circular(buttonRadius),
                            ),
                            backgroundColor: Colors.white,
                            elevation: 0,
                          ),
                          child: Text(
                            'ÜYE OL / KAYIT OL',
                            style: TextStyle(
                              fontSize: secondaryButtonFontSize,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: isCompactMobile ? 20 : 24),

                      // Divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'VEYA',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),

                      SizedBox(height: isCompactMobile ? 20 : 24),

                      // Google Login Button
                      SizedBox(
                        height: buttonHeight,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  setState(() => _isLoading = true);
                                  final navigator = Navigator.of(context);
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  try {
                                    final appState = Provider.of<AppState>(
                                      context,
                                      listen: false,
                                    );
                                    await appState.loginWithGoogle();
                                    if (!mounted) return;
                                    navigator.pushReplacement(
                                      buildAppPageRoute<void>(
                                        builder: (context) =>
                                            const HomeScreen(initialIndex: 4),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Giriş başarısız: ${e.toString()}',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isLoading = false);
                                    }
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(buttonRadius),
                            ),
                            backgroundColor: Colors.white,
                          ),
                          icon: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.g_mobiledata,
                              size: 28,
                              color: Colors.red,
                            ), // Basit Google ikonu placeholder
                          ),
                          label: Text(
                            'Google ile Giriş Yap',
                            style: TextStyle(
                              fontSize: tertiaryButtonFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Guest Login Button
                      TextButton(
                        onPressed: _isLoading || !AppFeatureFlags.allowGuestMode
                            ? null
                            : () {
                                final appState = Provider.of<AppState>(
                                  context,
                                  listen: false,
                                );
                                appState.login(
                                  UserIdentity.defaultGuestDisplayName,
                                  UserIdentity.guestEmail,
                                );
                                Navigator.pop(context);
                              },
                        child: Text(
                          'Misafir Olarak Devam Et',
                          style: TextStyle(
                            fontSize: isCompactMobile ? 15 : 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
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
