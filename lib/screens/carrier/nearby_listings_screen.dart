import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/api_client.dart';
import '../../services/location_gate.dart';
import '../../theme/bitasi_theme.dart';
import '../offer_amount_screen.dart';

class NearbyListingsScreen extends StatefulWidget {
  const NearbyListingsScreen({super.key});

  @override
  State<NearbyListingsScreen> createState() => _NearbyListingsScreenState();
}

class _NearbyListingsScreenState extends State<NearbyListingsScreen> {
  // State variables
  bool _isLoading = true;
  String? _error;
  List<dynamic> _listings = [];
  
  // Filters
  double _radius = 50.0;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _initLocationAndFetch();
  }

  Future<void> _initLocationAndFetch() async {
    try {
      final ok = await LocationGate.ensureReady(context: context);
      if (!ok) {
        setState(() {
          _error = 'Konum izni verilmedi.';
          _isLoading = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      
      _currentLocation = LatLng(pos.latitude, pos.longitude);
      await _fetchListings();

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Konum alınamadı: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchListings() async {
    if (_currentLocation == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await apiClient.fetchNearbyListings(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        radius: _radius,
      );
      
      if (!mounted) return;
      setState(() {
        _listings = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Yükler getirilemedi. Bağlantını kontrol et.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for modern feel
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: _buildFilterSection(),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
            )
          else if (_listings.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Bu yakınlıkta (${_radius.toInt()} km) yük bulunamadı.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    TextButton(
                      onPressed: () {
                         setState(() => _radius = 100);
                         _fetchListings();
                      },
                      child: const Text('Mesafeyi Arttır (100km)'),
                    )
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _listings[index];
                    return _buildListingCard(item);
                  },
                  childCount: _listings.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Text(
          'Yakınımdaki Yükler',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.withValues(alpha: 0.1), Colors.white],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mesafe: ${_radius.toInt()} km',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Icon(Icons.radar, color: Colors.blueAccent, size: 20),
            ],
          ),
          Slider(
            value: _radius,
            min: 10,
            max: 500,
            divisions: 49,
            activeColor: Colors.blueAccent,
            inactiveColor: Colors.blue.withValues(alpha: 0.1),
            label: '${_radius.toInt()} km',
            onChanged: (val) {
              setState(() => _radius = val);
            },
            onChangeEnd: (val) {
              _fetchListings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListingCard(Map<String, dynamic> item) {
    final title = item['title'] ?? 'Başlıksız Yük';
    final weight = item['weight']?.toString() ?? '0';
    final pickup = item['pickup_location'];
    // final dropoff = item['dropoff_location'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetailsModal(item),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon / Image
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping, color: Colors.orange),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.scale, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '$weight kg',
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                          const SizedBox(width: 12),
                          if (item['fragile'] == true) ...[
                             const Icon(Icons.broken_image, size: 14, color: Colors.redAccent),
                             const SizedBox(width: 4),
                             Text('Hassas', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Mock Location text if available or just generic
                      Row(
                        children: [
                          const Icon(Icons.my_location, size: 14, color: Colors.blueGrey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              // Using pickup lat/lng as placeholder text effectively
                              pickup != null 
                              ? 'Alış: ${pickup['lat']}, ${pickup['lng']}'
                              : 'Konum bilgisi yok',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Arrow
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailsModal(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DetailSheet(item: item),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  final Map<String, dynamic> item;
  const _DetailSheet({required this.item});

  @override
  Widget build(BuildContext context) {
     final title = item['title'] ?? 'Başlıksız';
     final desc = item['description'] ?? '';
     final weight = item['weight'] ?? 0;
     final listingId = item['id'];

     return Container(
       height: MediaQuery.of(context).size.height * 0.60,
       decoration: const BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
       ),
       padding: const EdgeInsets.all(24),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
           const SizedBox(height: 24),
           Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
           const SizedBox(height: 16),
           Text('Açıklama', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold)),
           const SizedBox(height: 4),
           Text(desc.isEmpty ? 'Açıklama yok' : desc, style: const TextStyle(fontSize: 16, color: Colors.black87)),
           const SizedBox(height: 16),
           Row(
             children: [
               _InfoBadge(icon: Icons.scale, label: '$weight kg'),
               const SizedBox(width: 12),
               if(item['fragile'] == true)
                 const _InfoBadge(icon: Icons.warning, label: 'Kırılabilir', color: Colors.red),
             ],
           ),
           const Spacer(),
           SizedBox(
             width: double.infinity,
             height: 56,
             child: ElevatedButton(
               onPressed: () {
                 Navigator.pop(context); // close sheet
                 _openOfferScreen(context, listingId, title);
               },
               style: ElevatedButton.styleFrom(
                 backgroundColor: BiTasiColors.primaryBlue,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                 elevation: 0,
               ),
               child: const Text('Teklif Ver', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
             ),
           )
         ],
       ),
     );
  }

  void _openOfferScreen(BuildContext context, String id, String title) {
     final navigator = Navigator.of(context);
     final messenger = ScaffoldMessenger.of(context);

     navigator
         .push(
       MaterialPageRoute(builder: (_) => OfferAmountScreen(title: title)),
     )
         .then((val) {
       if (val != null) {
          // send offer
          final amt = double.tryParse(val.toString().replaceAll(',', '.'));
          if (amt != null) {
             apiClient.createOffer(listingId: id, amount: amt).then((_) {
               messenger.showSnackBar(const SnackBar(content: Text('Teklif gönderildi!')));
             }).catchError((e) {
               messenger.showSnackBar(SnackBar(content: Text('Hata: $e')));
             });
          }
       }
     });
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoBadge({required this.icon, required this.label, this.color = Colors.blue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
