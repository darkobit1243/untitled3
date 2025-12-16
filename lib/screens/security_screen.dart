import 'package:flutter/material.dart';

import '../theme/trustship_theme.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _twoFactorEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Güvenlik')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _twoFactorEnabled,
                  activeThumbColor: TrustShipColors.primaryRed,
                  title: const Text('2 Adımlı Doğrulama (2FA)'),
                  subtitle: const Text(
                    'Hesabını ek bir doğrulama adımıyla koru.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  onChanged: (v) {
                    setState(() => _twoFactorEnabled = v);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(v ? '2FA etkinleştirildi.' : '2FA kapatıldı.')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('E-posta Ekle / Değiştir'),
                  subtitle: const Text(
                    'Giriş e-postanı güncelle.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showSimpleDialog(
                      title: 'E-posta Değiştir',
                      hint: 'yeni@ornek.com',
                      actionText: 'Kaydet',
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Şifre Değiştir'),
                  subtitle: const Text(
                    'Hesap şifreni yenile.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showSimpleDialog(
                      title: 'Şifre Değiştir',
                      hint: 'Yeni şifre',
                      actionText: 'Güncelle',
                      obscureText: true,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSimpleDialog({
    required String title,
    required String hint,
    required String actionText,
    bool obscureText = false,
  }) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            obscureText: obscureText,
            decoration: InputDecoration(hintText: hint),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: TrustShipColors.primaryRed),
              child: Text(actionText),
            ),
          ],
        );
      },
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Güncelleme isteği alındı.')),
      );
    }

    controller.dispose();
  }
}
