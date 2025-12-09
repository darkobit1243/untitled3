import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/trustship_theme.dart';
import 'create_shipment_screen.dart';
import 'deal_details_screen.dart';
import 'my_shipment_screen.dart';
import 'my_shipments_screen.dart';
import 'profile_screen.dart';

enum DashboardMode { sender, carrier }

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  final ApiClient _api = ApiClient();
  DashboardMode _mode = DashboardMode.sender;
  Future<List<dynamic>>? _listingsFuture;

  @override
  void initState() {
    super.initState();
    // TODO: Giriş akışı eklendiğinde gerçek token ile login yapılacak.
    _listingsFuture = _api.fetchListings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping, color: TrustShipColors.primaryRed),
            const SizedBox(width: 8),
            const Text('TrustShip'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              // Şimdilik placeholder: bildirimin olmadığı basit bir dialog.
              showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Bildirimler'),
                  content: const Text('Şu anda okunmamış bildiriminiz yok.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Kapat'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => _MainMenuSheet(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          _buildModeToggle(),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _listingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('İlanlar yüklenemedi: ${snapshot.error}'));
                }
                final listings = snapshot.data ?? [];
                if (_mode == DashboardMode.sender) {
                  return _SenderView(listings: listings);
                } else {
                  return _CarrierView(listings: listings);
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _mode == DashboardMode.sender
          ? FloatingActionButton(
              backgroundColor: TrustShipColors.primaryRed,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateShipmentScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: TrustShipColors.backgroundGrey,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'Ürün Gönder',
                selected: _mode == DashboardMode.sender,
                onTap: () {
                  setState(() => _mode = DashboardMode.sender);
                },
              ),
            ),
            Expanded(
              child: _ModeButton(
                label: 'Para Kazan',
                selected: _mode == DashboardMode.carrier,
                onTap: () {
                  setState(() => _mode = DashboardMode.carrier);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: TrustShipColors.textDarkGrey,
              ),
            ),
          ),
        ),
      );
    }

    return TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }
}

class _SenderView extends StatelessWidget {
  const _SenderView({required this.listings});

  final List<dynamic> listings;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Gönderileriniz',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: TrustShipColors.textDarkGrey,
              ),
            ),
          );
        }
        final listing = listings[index - 1] as Map<String, dynamic>;
        return _ShipmentCard(listing: listing);
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: (listings.length) + 1,
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({required this.listing});

  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    final title = listing['title'] as String? ?? 'Gönderi';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DealDetailsScreen(listing: listing),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: TrustShipColors.backgroundGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_shipping, color: TrustShipColors.primaryRed),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: TrustShipColors.textDarkGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Taşıyıcı: Aranıyor...',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TrustShipColors.warningOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Taşıyıcı Aranıyor',
                style: TextStyle(
                  color: TrustShipColors.warningOrange,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarrierView extends StatelessWidget {
  const _CarrierView({required this.listings});

  final List<dynamic> listings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Nereye gidiyorsunuz?',
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Rotanızdaki Uygun İşler',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: TrustShipColors.textDarkGrey,
          ),
        ),
        const SizedBox(height: 8),
        for (final raw in listings)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _JobCard(listing: raw as Map<String, dynamic>),
          ),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.listing});

  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    final title = listing['title'] as String? ?? 'Gönderi';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DealDetailsScreen(listing: listing),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place, color: TrustShipColors.primaryRed, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: TrustShipColors.textDarkGrey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: const [
                Text('Tarih bilinmiyor', style: TextStyle(color: Colors.grey, fontSize: 12)),
                SizedBox(width: 12),
                Text('Mesafe hesaplanmadı', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SizedBox(),
                Text(
                  'Teklif bekleniyor',
                  style: TextStyle(
                    color: TrustShipColors.successGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: const [
                Icon(Icons.lock, color: TrustShipColors.successGreen, size: 14),
                SizedBox(width: 4),
                Text(
                  'Emanet',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MainMenuSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('Kargolarım'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MyShipmentsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profil'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


