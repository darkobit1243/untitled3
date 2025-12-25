// lib/screens/auth/auth_flow_screen.dart
//
// Çok adımlı kayıt akışı:
// 1) Rol seçimi (gönderici / taşıyıcı)
// 2) Seçilen role göre basit kayıt formu
// Kayıttan sonra otomatik login yapıp MainWrapper'a yönlendirir.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/app_settings.dart';
import '../../services/local_notifications.dart';
import '../../services/push_config.dart';
import '../../services/push_notifications.dart';
import '../../utils/auth_flow/auth_flow_helpers.dart';
import '../../widgets/auth_flow/registration_form_view.dart';
import '../../widgets/auth_flow/role_selection_view.dart';
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
    _phoneHint = buildRandomTrPhoneHint();
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
    return AuthRoleSelectionView(
      onSelectSender: () {
        setState(() {
          _currentView = AuthView.senderRegistration;
        });
      },
      onSelectCarrier: () {
        setState(() {
          _currentView = AuthView.carrierRegistration;
        });
      },
    );
  }

  Widget _buildRegistrationForm({required String role}) {
    final isSender = role == 'sender';

    return AuthRegistrationFormView(
      isSender: isSender,
      scrollController: _scrollController,
      error: _error,
      isLoading: _isLoading,
      onBack: () {
        setState(() {
          _currentView = AuthView.roleSelection;
          _error = null;
        });
      },
      onSubmit: () => _handleRegister(role),
      onAnyFieldChanged: () {
        if (_error != null) setState(() => _error = null);
      },
      firstNameController: _firstNameController,
      lastNameController: _lastNameController,
      emailController: _emailController,
      passwordController: _passwordController,
      passwordConfirmController: _passwordConfirmController,
      phoneController: _phoneController,
      carrierVehicleTypeController: _carrierVehicleTypeController,
      carrierVehiclePlateController: _carrierVehiclePlateController,
      carrierServiceAreaController: _carrierServiceAreaController,
      kFirstName: _kFirstName,
      kLastName: _kLastName,
      kEmail: _kEmail,
      kPassword: _kPassword,
      kPasswordConfirm: _kPasswordConfirm,
      kPhone: _kPhone,
      kVehicleType: _kVehicleType,
      kVehiclePlate: _kVehiclePlate,
      firstNameFocus: _firstNameFocus,
      lastNameFocus: _lastNameFocus,
      emailFocus: _emailFocus,
      passwordFocus: _passwordFocus,
      passwordConfirmFocus: _passwordConfirmFocus,
      phoneFocus: _phoneFocus,
      vehicleTypeFocus: _vehicleTypeFocus,
      vehiclePlateFocus: _vehiclePlateFocus,
      phoneHint: _phoneHint,
    );
  }

  Future<void> _handleRegister(String role) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _passwordConfirmController.text;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = '$firstName $lastName'.trim();
    final phone = normalizeTrPhoneToE164(_phoneController.text);

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
          _error = friendlyFirebaseAuthError(e);
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

