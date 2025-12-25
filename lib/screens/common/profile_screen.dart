import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_client.dart';
import '../../services/background_tracking_service.dart';
import '../../services/app_settings.dart';
import '../../theme/bitasi_theme.dart';
import '../admin_dashboard_screen.dart';
import '../auth/login_screen.dart';
import '../vehicle_info_screen.dart';
import 'notifications_settings_screen.dart';
import 'payment_setup_screen.dart';
import 'security_screen.dart';
import 'support_faq_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _avatarUploading = false;
  Map<String, dynamic>? _profile;
  int _myListingsCount = 0;
  int _carrierDeliveriesCount = 0;
  String _preferredRole = 'sender';
  bool _notificationsEnabled = true;

  String _inferMimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _changeAvatar() async {
    if (_avatarUploading) return;

    setState(() {
      _avatarUploading = true;
    });

    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      final Uint8List bytes = await picked.readAsBytes();
      final mime = _inferMimeTypeFromPath(picked.path);

      final presign = await apiClient.presignUpload(
        contentType: mime,
        prefix: 'avatars',
      );
      final url = presign['url']?.toString();
      final key = presign['key']?.toString();
      final rawHeaders = presign['headers'];

      if (url == null || url.isEmpty || key == null || key.isEmpty) {
        throw Exception('Upload URL yanıtı geçersiz.');
      }

      final headers = <String, String>{};
      if (rawHeaders is Map) {
        for (final entry in rawHeaders.entries) {
          final k = entry.key?.toString();
          final v = entry.value?.toString();
          if (k != null && v != null) headers[k] = v;
        }
      }
      if (!headers.containsKey('Content-Type')) {
        headers['Content-Type'] = mime;
      }

      await apiClient.uploadToPresignedUrl(url: url, bytes: bytes, headers: headers);

      final updated = await apiClient.updateMyProfile(avatarUrl: key);

      if (!mounted) return;
      setState(() {
        _profile = updated;
        final roleValue = updated['role'];
        _preferredRole = (roleValue is String && roleValue.isNotEmpty) ? roleValue : _preferredRole;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotoğrafı güncellendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil fotoğrafı güncellenemedi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _avatarUploading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<dynamic>> _safeCarrierDeliveries() async {
    try {
      return await apiClient.fetchCarrierDeliveries();
    } catch (e) {
      if (e.toString().contains('403')) {
        return <dynamic>[];
      }
      rethrow;
    }
  }

  Future<List<dynamic>> _safeMyListings() async {
    try {
      return await apiClient.fetchMyListings();
    } catch (e) {
      if (e.toString().contains('403')) {
        return <dynamic>[];
      }
      rethrow;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final notifEnabled = await appSettings.getNotificationsEnabled();
      final profile = await apiClient.getProfile();
      final roleValue = profile['role'];
      final isCarrier = roleValue is String && roleValue == 'carrier';
      final myListingsFuture = isCarrier ? Future.value(<dynamic>[]) : _safeMyListings();
      final carrierDeliveriesFuture = isCarrier ? _safeCarrierDeliveries() : Future.value(<dynamic>[]);

      final results = await Future.wait([
        myListingsFuture,
        carrierDeliveriesFuture,
      ]);

      setState(() {
        _profile = profile;
        _myListingsCount = results[0].length;
        _carrierDeliveriesCount = results[1].length;
        _preferredRole = (roleValue is String && roleValue.isNotEmpty) ? roleValue : 'sender';
        _notificationsEnabled = notifEnabled;
      });
    } catch (e) {
      if (!mounted) return;
      final isForbidden = e.toString().contains('403');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isForbidden ? 'Yetersiz izin: Taşıyıcı verisi alınamadı.' : 'Profil bilgileri alınamadı: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _profile?['email']?.toString() ?? '-';
    final rawPublicId = _profile?['publicId'];
    final publicId = rawPublicId is num ? rawPublicId.toInt() : int.tryParse(rawPublicId?.toString() ?? '');
    final userId = publicId != null
        ? 'TS-${publicId.toString().padLeft(6, '0')}'
        : (_profile?['id']?.toString() ?? _profile?['sub']?.toString() ?? '-');

    return Scaffold(
      appBar: AppBar(title: const Text('Profil & Cüzdan')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              'Kullanıcı Bilgileri',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _loading ? const Center(child: CircularProgressIndicator()) : _buildProfileCard(email, userId),
            const SizedBox(height: 24),
            const Text(
              'Özet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatsRow(),
            const SizedBox(height: 32),
            if (_profile?['role'] == 'admin') ...[
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('ADMİN PANELİ'),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await BackgroundTrackingService.stop();
                  await apiClient.clearToken();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('Çıkış Yap'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(String email, String userId) {
    final roleLabel = _preferredRole == 'carrier' ? 'Taşıyıcı' : 'Gönderici';
    final fullName = _profile?['fullName']?.toString() ?? email;
    final phone = _profile?['phone']?.toString() ?? 'Telefon yok';
    final address = _profile?['address']?.toString() ?? 'Adres belirtilmemiş';
    final vehicleType = _profile?['vehicleType']?.toString();
    final vehiclePlate = _profile?['vehiclePlate']?.toString();
    final serviceArea = _profile?['serviceArea']?.toString();
    final isCarrier = _preferredRole == 'carrier';
    final avatarUrl = _profile?['avatarUrl']?.toString();
    final rating = (_profile?['rating'] as num?)?.toDouble();
    final delivered = (_profile?['deliveredCount'] as num?)?.toInt();

    ImageProvider? avatarProvider;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('data:image')) {
        final comma = avatarUrl.indexOf(',');
        if (comma > -1 && comma + 1 < avatarUrl.length) {
          try {
            avatarProvider = MemoryImage(base64Decode(avatarUrl.substring(comma + 1)));
          } catch (_) {
            avatarProvider = null;
          }
        }
      } else {
        avatarProvider = NetworkImage(avatarUrl);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 14),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              GestureDetector(
                onTap: _avatarUploading ? null : _changeAvatar,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: BiTasiColors.backgroundGrey,
                      backgroundImage: avatarProvider,
                      child: avatarProvider == null
                          ? const Icon(Icons.person, color: BiTasiColors.primaryRed, size: 32)
                          : null,
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(140),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _avatarUploading ? Icons.hourglass_top : Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_avatarUploading)
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(70),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('ID: $userId', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: BiTasiColors.primaryRed.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(roleLabel, style: const TextStyle(color: BiTasiColors.primaryRed)),
                    ),
                    if (rating != null || delivered != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (rating != null) ...[
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            Text(rating.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                          if (delivered != null) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.local_shipping, size: 14, color: Colors.grey),
                            Text('$delivered teslimat', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildSectionCard(
          title: 'Kişisel Bilgiler',
          child: Column(
            children: [
              _buildInfoRow('Telefon', phone),
              const SizedBox(height: 6),
              _buildInfoRow('Adres', address),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isCarrier)
          _buildSectionCard(
            title: 'Araç Yönetimi',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Araç Tipi', vehicleType ?? 'Tanımlı değil'),
                const SizedBox(height: 4),
                _buildInfoRow('Plaka', vehiclePlate ?? 'Tanımlı değil'),
                const SizedBox(height: 4),
                _buildInfoRow('Servis Bölgesi', serviceArea ?? 'Tanımlı değil'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  final current = _profile;
                  if (current == null) return;
                  final updated = await Navigator.of(context).push<Map<String, dynamic>>(
                    MaterialPageRoute(builder: (_) => VehicleInfoScreen(initialProfile: current)),
                  );
                  if (!mounted || updated == null) return;
                  setState(() {
                    _profile = updated;
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: BiTasiColors.primaryRed),
                child: const Text('Düzenle'),
              ),
            ],
          ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: 'Ödeme Bilgileri',
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Bakiye, cüzdan ve ödeme yöntemlerini buradan yönet.'),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PaymentSetupScreen()),
                );
              },
              child: const Text('Yöntem Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: 'Ayarlar',
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bildirimler'),
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: (v) async {
                    setState(() => _notificationsEnabled = v);
                    await appSettings.setNotificationsEnabled(v);
                  },
                ),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const NotificationsSettingsScreen()),
                  );
                  final enabled = await appSettings.getNotificationsEnabled();
                  if (!mounted) return;
                  setState(() => _notificationsEnabled = enabled);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Güvenlik'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SecurityScreen()),
                  );
                },
              ),
              if (isCarrier)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Araç Bilgileri'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final current = _profile;
                    if (current == null) return;
                    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
                      MaterialPageRoute(builder: (_) => VehicleInfoScreen(initialProfile: current)),
                    );
                    if (!mounted || updated == null) return;
                    setState(() {
                      _profile = updated;
                    });
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ödeme / IBAN'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const PaymentSetupScreen()),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Destek & SSS'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SupportFaqScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    List<Widget>? actions,
  }) {
    final borderRadius = BorderRadius.circular(18);

    return Material(
      color: Colors.white,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: Colors.black.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (actions != null)
                  Flexible(
                    fit: FlexFit.loose,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: actions,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Oluşturduğun ilanlar',
            value: _myListingsCount.toString(),
            icon: Icons.local_post_office_outlined,
            color: BiTasiColors.primaryRed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Taşıdığın kargolar',
            value: _carrierDeliveriesCount.toString(),
            icon: Icons.route_outlined,
            color: BiTasiColors.successGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: BiTasiColors.textDarkGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
