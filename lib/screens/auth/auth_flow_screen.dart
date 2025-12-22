// lib/screens/auth/auth_flow_screen.dart
//
// Çok adımlı kayıt akışı:
// 1) Rol seçimi (gönderici / taşıyıcı)
// 2) Seçilen role göre basit kayıt formu
// Kayıttan sonra otomatik login yapıp MainWrapper'a yönlendirir.

import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_client.dart';
import '../../services/app_settings.dart';
import '../../services/local_notifications.dart';
import '../../services/push_config.dart';
import '../../services/push_notifications.dart';
import '../../theme/app_ui.dart';
import '../../theme/bitasi_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/app_text_field.dart';
import '../main_wrapper.dart';
import 'otp_verification_screen.dart';
import '../sender/sender_company_info_screen.dart';

enum AuthView {
  roleSelection,
  senderRegistration,
  carrierRegistration,
}

class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({super.key});

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  AuthView _currentView = AuthView.roleSelection;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _carrierVehicleTypeController = TextEditingController();
  final _carrierVehiclePlateController = TextEditingController();
  final _carrierServiceAreaController = TextEditingController();

  final _scrollController = ScrollController();
  final _kFirstName = GlobalKey();
  final _kLastName = GlobalKey();
  final _kEmail = GlobalKey();
  final _kPassword = GlobalKey();
  final _kPasswordConfirm = GlobalKey();
  final _kPhone = GlobalKey();
  final _kVehicleType = GlobalKey();
  final _kVehiclePlate = GlobalKey();

  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _passwordConfirmFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _vehicleTypeFocus = FocusNode();
  final _vehiclePlateFocus = FocusNode();

  bool _isLoading = false;
  String? _error;
  int? _lastResendToken;

  late final String _phoneHint;

  @override
  void initState() {
    super.initState();
    _phoneHint = _buildRandomTrPhoneHint();
  }

  String _friendlyFirebaseAuthError(FirebaseAuthException e) {
    // Common Firebase Phone Auth errors.
    switch (e.code) {
      case 'billing-not-enabled':
        return 'SMS doğrulama için Firebase projesinde faturalandırma (Blaze) gerekir.\n\nSadece test amaçlıysa: Firebase Console > Authentication > Sign-in method > Phone > Test phone numbers kısmından test numarası ekleyip onunla deneyin.';
      case 'quota-exceeded':
        return 'SMS kotası aşıldı. Bir süre bekleyip tekrar deneyin.\n\nTest için: Firebase Console > Authentication > Phone > Test phone numbers.';
      case 'invalid-phone-number':
        return 'Telefon numarası geçersiz. 10 haneli 5xxxxxxxxx formatında gir.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen biraz bekleyip tekrar deneyin.';
      case 'captcha-check-failed':
      case 'invalid-app-credential':
      case 'app-not-authorized':
      case 'missing-client-identifier':
        return 'Uygulama doğrulanamadı (Play Integrity / reCAPTCHA).\n\nÇözüm: Firebase Console > Project settings > Android app (com.example.untitled) içine SHA-1 ve SHA-256 ekle, sonra yeni google-services.json indirip projeye koy. Google Cloud’da Play Integrity API açık olsun.\n\nDetay: ${e.code}: ${e.message ?? ''}'.trim();
      default:
        final msg = (e.message ?? '').trim();
        if (msg.isEmpty) return 'SMS doğrulama başlatılamadı. (${e.code})';
        return '${e.code}: $msg';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _carrierVehicleTypeController.dispose();
    _carrierVehiclePlateController.dispose();
    _carrierServiceAreaController.dispose();
    _scrollController.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _passwordConfirmFocus.dispose();
    _phoneFocus.dispose();
    _vehicleTypeFocus.dispose();
    _vehiclePlateFocus.dispose();
    super.dispose();
  }

  Future<void> _scrollToKey(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt Ol'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildCurrentView(),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case AuthView.roleSelection:
        return _buildRoleSelection();
      case AuthView.senderRegistration:
        return _buildRegistrationForm(role: 'sender');
      case AuthView.carrierRegistration:
        return _buildRegistrationForm(role: 'carrier');
    }
  }

  Widget _buildRoleSelection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nasıl kullanmak istiyorsun?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gönderici olarak kargo çıkabilir veya taşıyıcı olarak yolculuklarında ek gelir elde edebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _roleCard(
              icon: Icons.send_outlined,
              title: 'Gönderici',
              description: 'Paketlerini farklı şehirlere güvenle gönder.',
              color: BiTasiColors.primaryRed,
              onTap: () {
                setState(() {
                  _currentView = AuthView.senderRegistration;
                });
              },
            ),
            const SizedBox(height: 16),
            _roleCard(
              icon: Icons.directions_car,
              title: 'Taşıyıcı',
              description: 'Yolculuklarını kazanca çevir, kargo taşı.',
              color: BiTasiColors.successGreen,
              onTap: () {
                setState(() {
                  _currentView = AuthView.carrierRegistration;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withAlpha(89)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withAlpha(31),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm({required String role}) {
    final isSender = role == 'sender';

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _currentView = AuthView.roleSelection;
                    _error = null;
                  });
                },
                icon: const Icon(Icons.arrow_back_ios_new, size: 14),
                label: const Text('Geri'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSender ? 'Gönderici Kaydı' : 'Taşıyıcı Kaydı',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isSender
                    ? 'Paket göndermek için hızlıca bir hesap oluştur.'
                    : 'Yolculuklarında kargo taşıyıp gelir elde etmek için kayıt ol.',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      key: _kFirstName,
                      child: AppTextField(
                        label: 'İsim',
                        controller: _firstNameController,
                        hintText: 'Adınız (örn: Ahmet Can)',
                        prefixIcon: Icons.person_outline,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: const [TrNameFormatter()],
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        focusNode: _firstNameFocus,
                        nextFocusNode: _lastNameFocus,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Container(
                      key: _kLastName,
                      child: AppTextField(
                        label: 'Soyad',
                        controller: _lastNameController,
                        hintText: 'Soyadınız',
                        prefixIcon: Icons.badge_outlined,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: const [TrNameFormatter()],
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        focusNode: _lastNameFocus,
                        nextFocusNode: _emailFocus,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Container(
                      key: _kEmail,
                      child: AppTextField(
                        label: 'E-posta',
                        controller: _emailController,
                        hintText: 'ornek@eposta.com',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        focusNode: _emailFocus,
                        nextFocusNode: _passwordFocus,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Container(
                      key: _kPassword,
                      child: AppTextField(
                        label: 'Şifre',
                        controller: _passwordController,
                        hintText: 'En az 6 karakter',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        focusNode: _passwordFocus,
                        nextFocusNode: _passwordConfirmFocus,
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Container(
                      key: _kPasswordConfirm,
                      child: AppTextField(
                        label: 'Şifre (Tekrar)',
                        controller: _passwordConfirmController,
                        hintText: 'Şifreni tekrar gir',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        focusNode: _passwordConfirmFocus,
                        nextFocusNode: _phoneFocus,
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Container(
                      key: _kPhone,
                      child: _buildCommonFields(),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    if (!isSender) ...[
                      Container(key: _kVehicleType, child: _buildCarrierFields()),
                      const SizedBox(height: AppSpace.lg),
                    ],
                    AppButton.primary(
                      label: 'Kayıt Ol',
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : () => _handleRegister(role),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommonFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Telefon',
          controller: _phoneController,
          hintText: _phoneHint,
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: const [TrPhoneHyphenFormatter()],
          enabled: !_isLoading,
          textInputAction: TextInputAction.done,
          focusNode: _phoneFocus,
        ),
      ],
    );
  }

  String _buildRandomTrPhoneHint() {
    // 10 hane TR GSM: 5xxxxxxxxx
    final rnd = Random();
    final digits = StringBuffer('5');
    for (var i = 0; i < 9; i++) {
      digits.write(rnd.nextInt(10));
    }
    final raw = digits.toString();
    return '${raw.substring(0, 3)}-${raw.substring(3, 6)}-${raw.substring(6)}';
  }

  Widget _buildCarrierFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: _kVehicleType,
          child: AppTextField(
            label: 'Araç Tipi',
            controller: _carrierVehicleTypeController,
            hintText: 'Otomobil, panelvan, kamyonet vb.',
            prefixIcon: Icons.local_shipping_outlined,
            enabled: !_isLoading,
            textInputAction: TextInputAction.next,
            focusNode: _vehicleTypeFocus,
            nextFocusNode: _vehiclePlateFocus,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Container(
          key: _kVehiclePlate,
          child: AppTextField(
            label: 'Araç Plakası',
            controller: _carrierVehiclePlateController,
            hintText: '34ABC34',
            prefixIcon: Icons.badge_outlined,
            textCapitalization: TextCapitalization.characters,
            enabled: !_isLoading,
            textInputAction: TextInputAction.next,
            focusNode: _vehiclePlateFocus,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        AppTextField(
          label: 'Servis Bölgesi',
          controller: _carrierServiceAreaController,
          hintText: 'Çalıştığınız şehir / gece rotası',
          prefixIcon: Icons.public,
          enabled: !_isLoading,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Future<void> _handleRegister(String role) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _passwordConfirmController.text;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = '$firstName $lastName'.trim();
    final phone = _normalizePhone(_phoneController.text);

    if (email.isEmpty) {
      setState(() {
        _error = 'Lütfen e-posta gir.';
      });
      await _scrollToKey(_kEmail);
      return;
    }

    // E-posta format kontrolü.
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() {
        _error = 'Lütfen geçerli bir e-posta gir.';
      });
      await _scrollToKey(_kEmail);
      return;
    }

    if (firstName.isEmpty || lastName.isEmpty || phone == null) {
      setState(() {
        _error = 'İsim, soyad ve geçerli telefon (5xxxxxxxxx) bilgilerini gir.';
      });
      if (firstName.isEmpty) {
        await _scrollToKey(_kFirstName);
      } else if (lastName.isEmpty) {
        await _scrollToKey(_kLastName);
      } else {
        await _scrollToKey(_kPhone);
      }
      return;
    }
    if (password.length < 6) {
      setState(() {
        _error = 'Şifre en az 6 karakter olmalıdır.';
      });
      await _scrollToKey(_kPassword);
      return;
    }
    if (password != confirm) {
      setState(() {
        _error = 'Şifreler eşleşmiyor.';
      });
      await _scrollToKey(_kPasswordConfirm);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = <String, dynamic>{
        'fullName': fullName,
        'phone': phone,
      };
      if (role == 'sender') {
      } else {
        final vehicleType = _carrierVehicleTypeController.text.trim();
        final vehiclePlate = _carrierVehiclePlateController.text.trim();
        final serviceArea = _carrierServiceAreaController.text.trim();
        if (vehicleType.isEmpty || vehiclePlate.isEmpty) {
          setState(() {
            _error = 'Araç tipi ve plaka giriniz.';
          });
          await _scrollToKey(vehicleType.isEmpty ? _kVehicleType : _kVehiclePlate);
          return;
        }
        profile['vehicleType'] = vehicleType;
        profile['vehiclePlate'] = vehiclePlate;
        if (serviceArea.isNotEmpty) {
          profile['serviceArea'] = serviceArea;
        }
      }

      await _startPhoneVerification(
        role: role,
        email: email.isEmpty ? null : email,
        password: password,
        profile: profile,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Kayıt başarısız: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _normalizePhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // TR için kullanıcı genelde "544-567-5582" gibi girer.
    // Tire/boşluk/parantez vs. temizle, sadece rakamları al.
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    // Kabul edilen girişler:
    // - 10 hane: 5xxxxxxxxx  -> +90
    // - 11 hane: 05xxxxxxxxx -> +90
    // - 12 hane: 90 + 10 hane -> +90
    // - E.164 girilmişse (+90...) zaten digits=90...

    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length == 12 && digits.startsWith('90')) {
      digits = digits.substring(2);
    }

    // TR GSM numarası 10 hane ve 5 ile başlar.
    if (digits.length != 10 || !digits.startsWith('5')) {
      return null;
    }

    return '+90$digits';
  }

  Future<void> _startPhoneVerification({
    required String role,
    required String? email,
    required String password,
    required Map<String, dynamic> profile,
  }) async {
    final phone = profile['phone'] as String?;
    if (phone == null) {
      throw StateError('Telefon eksik');
    }

    // Firebase init (Firebase config eksikse kullanıcıya anlaşılır hata dönelim).
    try {
      await Firebase.initializeApp();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Firebase yapılandırması eksik. Lütfen Firebase Console ayarlarını tamamlayın.';
      });
      return;
    }

    final auth = FirebaseAuth.instance;

    await auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final userCred = await auth.signInWithCredential(credential);
          final idToken = await userCred.user?.getIdToken(true);
          if (idToken == null) {
            throw StateError('Firebase token alınamadı');
          }
          if (!mounted) return;

          if (role == 'sender') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => SenderCompanyInfoScreen(
                  firebaseIdToken: idToken,
                  email: email,
                  password: password,
                  profile: profile,
                ),
              ),
            );
            return;
          }

          await apiClient.registerWithFirebaseIdToken(
            idToken,
            role: role,
            email: email,
            password: password,
            profile: profile,
          );

          if (kEnableFirebasePush) {
            await pushNotifications.syncWithSettings();
          }

          // Welcome notification (best-effort).
          try {
            final enabled = await appSettings.getNotificationsEnabled();
            if (enabled) {
              final fullName = profile['fullName']?.toString().trim();
              final fallback = email?.trim().isNotEmpty == true ? email!.trim() : 'BiTaşı';
              await localNotifications.showWelcome(fullName: (fullName == null || fullName.isEmpty) ? fallback : fullName);
            }
          } catch (_) {
            // Ignore.
          }

          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainWrapper()),
            (route) => false,
          );
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _error = 'Doğrulama başarısız: ${e.toString()}';
          });
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() {
          _error = _friendlyFirebaseAuthError(e);
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        _lastResendToken = resendToken;

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              verificationId: verificationId,
              resendToken: resendToken,
              role: role,
              email: email,
              password: password,
              profile: profile,
            ),
          ),
        );
      },
      codeAutoRetrievalTimeout: (_) {},
      forceResendingToken: _lastResendToken,
    );
  }
}

class TrNameFormatter extends TextInputFormatter {
  const TrNameFormatter();

  String _upperTr(String s) {
    if (s.isEmpty) return s;
    return s
        .replaceAll('i', 'İ')
        .replaceAll('ı', 'I')
        .toUpperCase();
  }

  String _lowerTr(String s) {
    if (s.isEmpty) return s;
    return s
        .replaceAll('I', 'ı')
        .replaceAll('İ', 'i')
        .toLowerCase();
  }

  String _toNameCase(String input) {
    final endsWithSpace = input.isNotEmpty && RegExp(r'\s$').hasMatch(input);
    final normalized = input.replaceAll(RegExp(r'\s+'), ' ').trimLeft();
    if (normalized.isEmpty) return '';

    final parts = normalized.split(' ');
    final cased = parts.map((p) {
      final word = p.trim();
      if (word.isEmpty) return '';
      if (word.length == 1) return _upperTr(word);
      final first = _upperTr(word[0]);
      final rest = _lowerTr(word.substring(1));
      return '$first$rest';
    }).where((p) => p.isNotEmpty);
    final result = cased.join(' ');

    // Kullanıcı ikinci isme geçmek için boşluk yazdığında, formatter boşluğu anında
    // silmesin; tek bir trailing boşluğu koru.
    if (endsWithSpace && result.isNotEmpty) {
      return '$result ';
    }
    return result;
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = _toNameCase(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Turkish phone input formatter that auto-inserts hyphens in 3-3-4 format.
///
/// User types digits only; formatter displays like: 544-567-5582.
class TrPhoneHyphenFormatter extends TextInputFormatter {
  const TrPhoneHyphenFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    // TR GSM numbers should start with 5 (e.g., 5xxxxxxxxx). If user starts with
    // something else, force it to 5.
    if (digits.isNotEmpty && digits[0] != '5') {
      digits = digits.length == 1 ? '5' : '5${digits.substring(1)}';
    }

    final formatted = _format(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length <= 3) return digits;
    if (digits.length <= 6) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }
    return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
  }
}


