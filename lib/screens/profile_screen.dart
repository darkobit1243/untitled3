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

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final profile = await apiClient.getProfile();
      final roleValue = profile['role'];
      final isCarrier = roleValue is String && roleValue == 'carrier';
      final myListingsFuture = apiClient.fetchMyListings();
      final carrierDeliveriesFuture = isCarrier
          ? apiClient.fetchCarrierDeliveries()
          : Future.value(<dynamic>[]);

      final results = await Future.wait([
        myListingsFuture,
        carrierDeliveriesFuture,
      ]);

      setState(() {
        _profile = profile;
        _myListingsCount = (results[0] as List<dynamic>).length;
        _carrierDeliveriesCount = (results[1] as List<dynamic>).length;
        _preferredRole = (roleValue is String && roleValue.isNotEmpty) ? roleValue : 'sender';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil bilgileri alınamadı: $e')),
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
    final fullName = _profile?['fullName']?.toString();
    final phone = _profile?['phone']?.toString();
    final address = _profile?['address']?.toString();
    final vehicleType = _profile?['vehicleType']?.toString();
    final vehiclePlate = _profile?['vehiclePlate']?.toString();
    final serviceArea = _profile?['serviceArea']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: TrustShipColors.backgroundGrey,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.person, size: 28, color: TrustShipColors.primaryRed),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName ?? email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: TrustShipColors.textDarkGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $userId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: TrustShipColors.primaryRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  roleLabel,
                  style: const TextStyle(color: TrustShipColors.primaryRed, fontWeight: FontWeight.w600),
                ),
              ),
              if (phone != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: TrustShipColors.backgroundGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    phone,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
          if (address != null || vehicleType != null || vehiclePlate != null || serviceArea != null) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (address != null)
                  Text('Adres: $address', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                if (vehicleType != null)
                  Text('Araç: $vehicleType', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                if (vehiclePlate != null)
                  Text('Plaka: $vehiclePlate', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                if (serviceArea != null)
                  Text('Servis: $serviceArea', style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ],
        ],
      ),
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