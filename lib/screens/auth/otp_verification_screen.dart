import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../services/api_client.dart';
import '../../theme/bitasi_theme.dart';
import '../main_wrapper.dart';
import '../sender/sender_company_info_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.resendToken,
    required this.role,
    required this.email,
    required this.password,
    required this.profile,
  });

  final String verificationId;
  final int? resendToken;
  final String role;
  final String? email;
  final String password;
  final Map<String, dynamic> profile;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();

  bool _isVerifying = false;
  String? _error;

  static const int _cooldownSeconds = 60;
  int _secondsLeft = _cooldownSeconds;
  Timer? _timer;

  String _verificationId = '';
  int? _resendToken;

  String _friendlyFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'billing-not-enabled':
        return 'SMS doğrulama için Firebase projesinde faturalandırma (Blaze) gerekir.\n\nSadece test amaçlıysa: Firebase Console > Authentication > Sign-in method > Phone > Test phone numbers kısmından test numarası ekleyip onunla deneyin.';
      case 'quota-exceeded':
        return 'SMS kotası aşıldı. Bir süre bekleyip tekrar deneyin.\n\nTest için: Firebase Console > Authentication > Phone > Test phone numbers.';
      case 'invalid-verification-code':
        return 'Kod hatalı. Lütfen tekrar deneyin.';
      case 'session-expired':
        return 'Kodun süresi doldu. Tekrar kod isteyin.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen biraz bekleyip tekrar deneyin.';
      case 'invalid-verification-id':
        return 'Doğrulama oturumu geçersiz. Tekrar kod isteyin.';
      default:
        return e.message ?? 'İşlem başarısız.';
    }
  }

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = _cooldownSeconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() {
          _secondsLeft = 0;
        });
        return;
      }
      setState(() {
        _secondsLeft -= 1;
      });
    });
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() {
        _error = 'Lütfen 6 haneli kodu gir.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      // Firebase init (no-op if already initialized)
      try {
        await Firebase.initializeApp();
      } catch (_) {}

      final auth = FirebaseAuth.instance;
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );

      final userCred = await auth.signInWithCredential(credential);
      final idToken = await userCred.user?.getIdToken(true);
      if (idToken == null) {
        throw StateError('Firebase token alınamadı');
      }

      if (!mounted) return;

      if (widget.role == 'sender') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SenderCompanyInfoScreen(
              firebaseIdToken: idToken,
              email: widget.email,
              password: widget.password,
              profile: widget.profile,
            ),
          ),
        );
        return;
      }

      await apiClient.registerWithFirebaseIdToken(
        idToken,
        role: widget.role,
        email: widget.email,
        password: widget.password,
        profile: widget.profile,
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainWrapper()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyFirebaseAuthError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Doğrulama başarısız: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (_secondsLeft > 0) return;

    final phone = widget.profile['phone'] as String?;
    if (phone == null) {
      setState(() {
        _error = 'Telefon bulunamadı.';
      });
      return;
    }

    setState(() {
      _error = null;
    });

    try {
      try {
        await Firebase.initializeApp();
      } catch (_) {}

      final auth = FirebaseAuth.instance;

      await auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (_) {},
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _error = _friendlyFirebaseAuthError(e);
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!mounted) return;
          _startTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Kod tekrar gönderilemedi: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Doğrulama'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Telefonunu doğrulamak için SMS ile gelen 6 haneli kodu gir.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
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
                  PinCodeTextField(
                    appContext: context,
                    length: 6,
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    autoDismissKeyboard: true,
                    animationType: AnimationType.fade,
                    enableActiveFill: true,
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(12),
                      fieldHeight: 54,
                      fieldWidth: 44,
                      activeFillColor: Colors.white,
                      inactiveFillColor: Colors.white,
                      selectedFillColor: Colors.white,
                      activeColor: BiTasiColors.primaryRed,
                      inactiveColor: Colors.grey.shade300,
                      selectedColor: BiTasiColors.primaryRed,
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
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BiTasiColors.primaryRed,
                      ),
                      onPressed: _isVerifying ? null : _verifyCode,
                      child: _isVerifying
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Doğrula',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _secondsLeft > 0 ? null : _resendCode,
                    child: Text(
                      _secondsLeft > 0
                          ? 'Kodu tekrar gönder (${_secondsLeft}s)'
                          : 'Kodu Tekrar Gönder',
                    ),
                  ),
                  TextButton(
                    onPressed: _isVerifying
                        ? null
                        : () {
                            Navigator.of(context).maybePop();
                          },
                    child: const Text('Telefonu değiştir'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
