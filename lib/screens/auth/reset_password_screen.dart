import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../theme/bitasi_theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
    this.initialCode,
  });

  final String email;
  final String? initialCode;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final TextEditingController _codeController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmController;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode ?? '');
    _passwordController = TextEditingController();
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    final pw = _passwordController.text;
    final pw2 = _confirmController.text;

    if (code.isEmpty) {
      setState(() => _error = 'Kodunu gir.');
      return;
    }
    if (pw.trim().length < 6) {
      setState(() => _error = 'Şifre en az 6 karakter olmalı.');
      return;
    }
    if (pw != pw2) {
      setState(() => _error = 'Şifreler uyuşmuyor.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      await apiClient.resetPassword(email: widget.email, code: code, newPassword: pw);
      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Şifren güncellendi. Giriş yapabilirsin.')),
      );
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Kod hatalı veya süresi dolmuş olabilir.');
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
      appBar: AppBar(title: const Text('Yeni Şifre')),
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
                    Text(
                      widget.email,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kod',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '6 haneli kod',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Yeni Şifre',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Yeni Şifre (Tekrar)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmController,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icon(Icons.lock_outline),
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
                                'Şifreyi Yenile',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
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
