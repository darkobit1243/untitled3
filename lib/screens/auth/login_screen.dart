// lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/push_notifications.dart';
import '../../services/push_config.dart';
import '../../theme/bitasi_theme.dart';
import 'auth_flow_screen.dart';
import '../main_wrapper.dart'; // Giriş başarılı olursa buraya gidecek

const String kLoginHeaderLogoTextAssetPath = 'assets/branding/app_logo_metin.png';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Lütfen e-posta ve şifre gir.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await apiClient.login(email, password);
      if (kEnableFirebasePush) {
        await pushNotifications.syncWithSettings();
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainWrapper()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'E-posta veya şifre hatalı. Tekrar deneyin.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final brandRed = BiTasiColors.bitasiRed;
    final loginTheme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: brandRed,
        secondary: brandRed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandRed,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: brandRed.withAlpha(120)),
          foregroundColor: brandRed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: brandRed, width: 2),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: brandRed,
      body: SafeArea(
        child: Theme(
          data: loginTheme,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header (logo text)
                    Padding(
                      padding: const EdgeInsets.only(top: 18, bottom: 10),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final logoWidth = (constraints.maxWidth * 0.94).clamp(320.0, 440.0);
                          return Column(
                            children: [
                              Image.asset(
                                kLoginHeaderLogoTextAssetPath,
                                width: logoWidth,
                                height: 128,
                                fit: BoxFit.fitWidth,
                                filterQuality: FilterQuality.high,
                                semanticLabel: 'BiTaşı',
                                errorBuilder: (_, __, ___) => const Text(
                                  'BiTaşı',
                                  style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Eşler arası güvenli lojistik platformu',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // Login Card
                    const SizedBox(height: 22),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          const Text(
                            'Giriş Yap',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: BiTasiColors.textDarkGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Hesabına erişmek için bilgilerini gir.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: BiTasiColors.errorRed.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: BiTasiColors.errorRed.withAlpha(64)),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: BiTasiColors.errorRed, fontSize: 13),
                              ),
                            ),
                          ],

                          const Text(
                            'E-posta Adresi',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'ornek@eposta.com',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            onChanged: (_) {
                              if (_error != null) {
                                setState(() {
                                  _error = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Şifre',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  // Şifremi unuttum
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Şifremi unuttum',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            onChanged: (_) {
                              if (_error != null) {
                                setState(() {
                                  _error = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Giriş Yap',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          Row(
                            children: const [
                              Expanded(child: Divider()),
                              SizedBox(width: 8),
                              Text('Hesabın yok mu?', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              SizedBox(width: 8),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 12),

                          OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AuthFlowScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('Kayıt Ol'),
                          ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Devam ederek BiTaşı Kullanım Şartları ve Gizlilik Politikası\'nı kabul etmiş olursunuz.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
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
    );
  }
}