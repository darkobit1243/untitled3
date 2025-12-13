import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/trustship_theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _profile;
  int _myListingsCount = 0;
  int _carrierDeliveriesCount = 0;
  String _preferredRole = 'sender';

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
      final profile = await apiClient.getProfile();
      final roleValue = profile['role'];
      final isCarrier = roleValue is String && roleValue == 'carrier';
      final myListingsFuture = isCarrier
          ? Future.value(<dynamic>[])
          : _safeMyListings();
      final carrierDeliveriesFuture = isCarrier
          ? _safeCarrierDeliveries()
          : Future.value(<dynamic>[]);

      final results = await Future.wait([
        myListingsFuture,
        carrierDeliveriesFuture,
      ]);

      setState(() {
        _profile = profile;
        _myListingsCount = results[0].length;
        _carrierDeliveriesCount = results[1].length;
        _preferredRole = (roleValue is String && roleValue.isNotEmpty) ? roleValue : 'sender';
      });
    } catch (e) {
      if (!mounted) return;
      final isForbidden = e.toString().contains('403');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isForbidden
              ? 'Yetersiz izin: Taşıyıcı verisi alınamadı.'
              : 'Profil bilgileri alınamadı: $e'),
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
    final userId = _profile?['sub']?.toString() ?? '-';

    return Scaffold(
      appBar: AppBar(title: const Text('Profil & Cüzdan')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kullanıcı Bilgileri',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildProfileCard(email, userId),
              const SizedBox(height: 24),
              const Text(
                'Özet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildStatsRow(),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
      decoration: BoxDecoration(
        color: Colors.white,
            borderRadius: BorderRadius.circular(22),
        boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14),
        ],
      ),
          padding: const EdgeInsets.all(18),
      child: Row(
        children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: TrustShipColors.backgroundGrey,
                child: const Icon(Icons.person, color: TrustShipColors.primaryRed, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    Text(fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('ID: $userId', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: TrustShipColors.primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(roleLabel, style: const TextStyle(color: TrustShipColors.primaryRed)),
                ),
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
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: TrustShipColors.primaryRed),
                child: const Text('Araç Ekle'),
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
              onPressed: () {},
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
                trailing: Switch(value: true, onChanged: (_) {}),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Güvenlik'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (actions != null) Row(children: actions),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
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
            color: TrustShipColors.primaryRed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Taşıdığın kargolar',
            value: _carrierDeliveriesCount.toString(),
            icon: Icons.route_outlined,
            color: TrustShipColors.successGreen,
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
            color: Colors.black.withOpacity(0.04),
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
              color: color.withOpacity(0.1),
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
                    color: TrustShipColors.textDarkGrey,
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