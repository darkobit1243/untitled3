import 'package:flutter/material.dart';

import '../../services/app_settings.dart';
import '../../services/push_notifications.dart';
import '../../services/push_config.dart';
import '../../theme/bitasi_theme.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  bool _loading = true;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await appSettings.getNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    await appSettings.setNotificationsEnabled(value);
    if (kEnableFirebasePush) {
      await pushNotifications.syncWithSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                  child: ListTile(
                    title: const Text('Bildirimleri Aç/Kapat'),
                    subtitle: const Text(
                      'Teklif ve mesaj bildirimlerini yönet.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: Switch(
                      value: _enabled,
                      activeThumbColor: BiTasiColors.primaryRed,
                      onChanged: _toggle,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Not: Bildirimler kapalıyken uygulama içi uyarılar ve yerel bildirimler gösterilmez.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
    );
  }
}
