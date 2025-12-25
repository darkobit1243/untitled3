import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../theme/bitasi_theme.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, String? initialEmail}) : initialEmail = initialEmail ?? '';

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'E-posta adresini gir.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final res = await apiClient.requestPasswordReset(email);
      if (!mounted) return;

      final debugCode = res['debugCode']?.toString();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            email: email,
            initialCode: debugCode,
          ),
        ),
      );

      messenger.showSnackBar(
        const SnackBar(content: Text('Sıfırlama kodu gönderildi.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'İstek gönderilemedi. Tekrar dene.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şifre Sıfırlama')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'E-posta Adresi',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(
                        hintText: 'ornek@eposta.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
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
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Kodu Gönder',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kodu aldıktan sonra yeni şifre belirleyebilirsin.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
