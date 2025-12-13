// lib/screens/home_screen.dart

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/api_client.dart';
import '../theme/trustship_theme.dart';
import 'create_shipment_screen.dart';
import 'ilanlar_screen.dart';
import 'teklif_listesi_sheet.dart';

// REST (Places / Directions) için özel key (yalnızca HTTP istekleri için)
const String _googleApiKey = 'AIzaSyBJu0tWf3dKoJV6m5r_tp02sOYSOUpgCV0';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.role = 'sender'});

  final String role;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Dio _dio = Dio();
  CancelToken? _placesCancelToken;

  bool _showNearbyCard = true;

  // Listings
  List<dynamic> _listings = [];
  bool _isLoading = false;
  List<dynamic> _senderActiveListings = [];
  List<Map<String, dynamic>> _nearestListings = [];

  // Google Maps state
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
      ),
    );
  }
  String? _selectedAddress;
  LatLng? _currentLocation;
  int? _senderListingCount;
  int? _senderPendingOffersCount;
  int? _carrierDeliveryCount;
  bool _roleSummaryLoading = false;
  String? _roleSummaryError;
  final List<dynamic> _senderListings = [];
  final List<dynamic> _carrierDeliveries = [];

  // Places autocomplete state
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _placePredictions = [];
  Timer? _debounce;

  // Başlangıç Konumu (Örn: İstanbul)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 10,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCurrentLocation());
    _loadRoleData();
    if (widget.role != 'carrier') {
      _loadListings();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCarrier = widget.role == 'carrier';
    // Güvenlik kontrolü: Eğer kullanıcı sender ise hiçbir şekilde carrier view görmemeli
    final actualIsCarrier = isCarrier;
    return Scaffold(
      body: actualIsCarrier ? _buildCarrierBody() : _buildSenderBody(context),
      floatingActionButton: isCarrier ? null : _buildSenderFab(),
      floatingActionButtonLocation:
          isCarrier ? FloatingActionButtonLocation.endFloat : FloatingActionButtonLocation.centerDocked,
    );
  }

  Future<void> _loadListings() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await apiClient.fetchListings();
      final nearest = await _getNearestListings();
      setState(() {
        _listings = data;
        _senderActiveListings = data.take(5).toList();
        _nearestListings = nearest;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İlanlar alınamadı, bağlantını kontrol et.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openListingsBottomSheet() async {
    if (_listings.isEmpty) {
      await _loadListings();
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        if (_isLoading) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (_listings.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Henüz ilan yok.')),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView.separated(
            itemCount: _listings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _listings[index] as Map<String, dynamic>;
              final title = item['title']?.toString() ?? 'Başlık yok';
              final desc = item['description']?.toString() ?? '';
              final weight = item['weight']?.toString() ?? '-';
              final listingId = item['id']?.toString() ?? '';

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: TrustShipColors.backgroundGrey,
                          borderRadius: BorderRadius.circular(10),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: TrustShipColors.textDarkGrey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: TrustShipColors.backgroundGrey,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$weight kg',
                                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: listingId.isEmpty ? null : () => _openOffersSheet(listingId, title),
                        icon: const Icon(Icons.local_offer, size: 18),
                        label: const Text('Teklifleri Gör'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRoleSummaryCard() {
    final isSender = widget.role == 'sender';
    final title = isSender ? 'Gönderici Paneli' : 'Taşıyıcı Paneli';
    String subtitle;
    if (_roleSummaryLoading) {
      subtitle = 'Yükleniyor...';
    } else if (_roleSummaryError != null) {
      subtitle = _roleSummaryError!;
    } else if (isSender) {
      final offersTxt = _senderPendingOffersCount != null ? ' • ${_senderPendingOffersCount} bekleyen teklif' : '';
      subtitle = '${_senderListingCount ?? 0} ilan$offersTxt';
    } else {
      subtitle = '${_carrierDeliveryCount ?? 0} teslimat';
    }

    return _buildSummaryCard(
      title: title,
      subtitle: subtitle,
      highlights: [
        Icon(
          isSender ? Icons.local_shipping : Icons.route,
          color: Colors.black54,
          size: 20,
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String subtitle,
    required List<Widget> highlights,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
            const Spacer(),
            ...highlights,
          ],
        ),
      ),
    );
  }

  Future<void> _loadRoleData() async {
    if (_roleSummaryLoading) return;
    setState(() {
      _roleSummaryLoading = true;
      _roleSummaryError = null;
    });

    try {
      if (widget.role == 'sender') {
        final listings = await apiClient.fetchMyListings();
        final offers = await apiClient.fetchOffersByOwner();
        final pending = offers.where((o) => (o['status']?.toString() ?? '') == 'pending').length;
        if (!mounted) return;
        setState(() {
          _senderListingCount = listings.length;
          _senderPendingOffersCount = pending;
          _senderListings
            ..clear()
            ..addAll(listings);
        });
      } else if (widget.role == 'carrier') {
        final deliveries = await apiClient.fetchCarrierDeliveries();
        if (!mounted) return;
        setState(() {
          _carrierDeliveryCount = deliveries.length;
          _carrierDeliveries
            ..clear()
            ..addAll(deliveries);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _roleSummaryError = 'Veri alınamadı';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _roleSummaryLoading = false;
      });
    }
  }

  Widget _buildSearchAndSummaryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRoleSummaryCard(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Adres veya yer ara...',
                      border: InputBorder.none,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionList() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        shrinkWrap: true,
        itemCount: _placePredictions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _placePredictions[index] as Map<String, dynamic>;
          final description = item['description']?.toString() ?? '';
          return ListTile(
            leading: const Icon(Icons.location_on_outlined, color: Colors.redAccent),
            title: Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              final placeId = item['place_id']?.toString();
              if (placeId != null) {
                _onPlaceSelected(placeId, description);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildNearbyListings(List<Map<String, dynamic>> listings) {
    if (listings.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Text(
                  'Yakın İlanlar',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _showNearbyCard = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: listings.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = listings[index];
                final pickup = item['pickup_location']?['address']?.toString() ?? '?';
                final dropoff = item['dropoff_location']?['address']?.toString() ?? '?';
                final distance = (item['__distance'] as double?)?.toStringAsFixed(1) ?? '?';
                final title = item['title']?.toString() ?? 'İlan';
                final price = item['price']?.toString() ?? 'Teklif yok';
                final weight = item['weight']?.toString() ?? '-';

                return Container(
                  width: 230,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.my_location, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              pickup,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.place, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              dropoff,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _chip('$weight kg'),
                          const SizedBox(width: 6),
                          _chip('$distance km'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(price, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.info_outline, size: 16, color: Colors.black54),
                            label: const Text('Detay', style: TextStyle(color: Colors.black87, fontSize: 12)),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final currentUserId = await apiClient.getCurrentUserId();
                              final listingOwnerId = item['ownerId']?.toString();
                              if (currentUserId == listingOwnerId) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Kendi ilanınıza teklif veremezsiniz.')),
                                );
                                return;
                              }
                              _showOfferDialog(item['id']?.toString() ?? '', title);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TrustShipColors.primaryRed,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            child: const Text('Teklif Ver'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarrierBody() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _initialPosition,
          myLocationEnabled: _currentLocation != null,
          zoomControlsEnabled: false,
          markers: _markers,
          polylines: _polylines,
          onMapCreated: (controller) => _mapController = controller,
          onTap: _onMapTap,
        ),
        Positioned(
          top: 40,
          left: 20,
          right: 20,
          child: Column(
            children: [
              _buildSearchAndSummaryCard(context),
              if (_placePredictions.isNotEmpty) _buildPredictionList(),
            ],
          ),
        ),
        if (_showNearbyCard)
          Positioned(
            bottom: 150,
            left: 20,
            right: 20,
            child: _buildNearbyListings(_nearestListings),
          ),
        Positioned(
          bottom: 90,
          right: 16,
          child: _buildActionButton(
            context,
            icon: Icons.directions_car,
            label: 'Rota\nBul',
            color: TrustShipColors.successGreen,
            onTap: () {
              if (_markers.isNotEmpty) {
                final dest = _markers.last.position;
                _drawRoute(_initialPosition.target, dest);
              }
            },
          ),
        ),
        Positioned(
          bottom: 20,
          right: 16,
          child: Row(
            children: [
              FloatingActionButton(
                onPressed: _goToCurrentLocation,
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: TrustShipColors.primaryRed),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const IlanlarScreen()),
                  );
                },
                backgroundColor: TrustShipColors.primaryRed,
                icon: const Icon(Icons.list_alt),
                label: const Text('İlanlar'),
              ),
            ],
          ),
        ),
        if (_selectedAddress != null)
          Positioned(
            bottom: 140,
            left: 20,
            right: 20,
            child: _buildSelectedAddressChip(),
          ),
      ],
    );
  }

  Widget _buildSenderBody(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gönderici Paneli', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Güncel Durum: ${_senderActiveListings.length} Teklif Bekleyen · ${_carrierDeliveryCount ?? 0} Yoldaki Gönderi',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildSearchAndSummaryCard(context),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 180,
                child: GoogleMap(
                  initialCameraPosition: _initialPosition,
                  markers: _markers,
                  zoomControlsEnabled: false,
                  myLocationEnabled: _currentLocation != null,
                  onMapCreated: (controller) => _mapController = controller,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _senderActiveListings.length,
              itemBuilder: (context, index) {
                final listing = _senderActiveListings[index] as Map<String, dynamic>;
                final title = listing['title']?.toString() ?? 'Başlık yok';
                final pickup = listing['pickup_location']?['lat']?.toStringAsFixed(2) ?? '?';
                final dropoff = listing['dropoff_location']?['lat']?.toStringAsFixed(2) ?? '?';
                final weight = listing['weight']?.toString() ?? '-';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: TrustShipColors.primaryRed.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('Teklif Bekliyor', style: const TextStyle(color: TrustShipColors.primaryRed)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Pickup: $pickup · Drop: $dropoff', style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 6),
                          Text('$weight kg', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => _openListingsBottomSheet(),
                                child: const Text('Teklifleri Gör'),
                              ),
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TrustShipColors.primaryRed,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Detay'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderFab() {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateShipmentScreen()),
        );
      },
      backgroundColor: TrustShipColors.primaryBlue,
      icon: const Icon(Icons.add),
      label: const Text('Yeni Gönderi'),
    );
  }

  Widget _buildSelectedAddressChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Row(
        children: [
          const Icon(Icons.place, color: TrustShipColors.primaryRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedAddress!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getNearestListings() async {
    if (_currentLocation == null || _listings.isEmpty) return [];
    final current = _currentLocation!;

    // Get current user ID to filter out own listings
    String? currentUserId;
    try {
      currentUserId = await apiClient.getCurrentUserId();
    } catch (_) {
      // If we can't get user ID, just return empty list for safety
      return [];
    }

    final list = List<Map<String, dynamic>>.from(_listings.cast<Map<String, dynamic>>())
        .where((item) => item['ownerId']?.toString() != currentUserId) // Filter out own listings
        .toList();

    list.sort((a, b) {
      final da = _distanceToListing(a, current);
      final db = _distanceToListing(b, current);
      return da.compareTo(db);
    });
    return list.take(5).map((item) {
      final copy = Map<String, dynamic>.from(item);
      copy['__distance'] = _distanceToListing(item, current);
      return copy;
    }).toList();
  }

  double _distanceToListing(Map<String, dynamic> item, LatLng base) {
    final pickup = item['pickup_location'] as Map<String, dynamic>?;
    if (pickup == null) return double.infinity;
    final lat = (pickup['lat'] as num?)?.toDouble() ?? base.latitude;
    final lng = (pickup['lng'] as num?)?.toDouble() ?? base.longitude;
    return Geolocator.distanceBetween(base.latitude, base.longitude, lat, lng) / 1000;
  }
  // --- Google Places & Directions helpers ---
  // Map'e tıklayınca: marker koy + Geocoding API ile adres bul.
  Future<void> _onMapTap(LatLng position) async {
    setState(() {
      _markers
        ..clear()
        ..add(
          Marker(
            markerId: const MarkerId('tap_place'),
            position: position,
          ),
        );
      _polylines.clear();
      _selectedAddress = null;
    });

    final address = await _reverseGeocode(position);
    if (!mounted) return;
    if (address != null) {
      setState(() {
        _selectedAddress = address;
        _searchController.text = address;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.isEmpty) {
      setState(() {
        _placePredictions = [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () {
      _fetchPlacePredictions(value);
    });
  }

  Future<void> _fetchPlacePredictions(String input) async {
    try {
      _placesCancelToken?.cancel();
      _placesCancelToken = CancelToken();
      final params = <String, dynamic>{
        'input': input,
        'key': _googleApiKey,
        'language': 'tr',
        'components': 'country:tr',
      };

      // Kullanıcının konumuna yakın sonuçları öne çıkar.
      if (_currentLocation != null) {
        params['location'] = '${_currentLocation!.latitude},${_currentLocation!.longitude}';
        params['radius'] = 50000; // 50km
        params['strictbounds'] = 'true';
      }

      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: params,
        cancelToken: _placesCancelToken,
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data as String) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _placePredictions = (data['predictions'] as List<dynamic>? ?? []);
      });
    } catch (_) {
      // Sessiz geç; UI'de ayrı bir hata göstermek istemiyoruz.
    }
  }

  Future<void> _initCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);

      if (!mounted) return;
      setState(() {
        _currentLocation = latLng;
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 12),
        ),
      );
    } catch (_) {
      // Sessiz geç.
    }
  }

  Future<void> _onPlaceSelected(String placeId, String description) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: <String, dynamic>{
          'place_id': placeId,
          'key': _googleApiKey,
          'fields': 'geometry/location',
        },
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data as String) as Map<String, dynamic>;

      final location = (data['result']?['geometry']?['location']) as Map<String, dynamic>?;
      if (location == null) return;

      final lat = (location['lat'] as num).toDouble();
      final lng = (location['lng'] as num).toDouble();
      final target = LatLng(lat, lng);

      _placePredictions = [];
      _searchController.text = description;

      setState(() {
        _markers
          ..clear()
          ..add(
            Marker(
              markerId: const MarkerId('selected_place'),
              position: target,
              infoWindow: InfoWindow(title: description),
            ),
          );
        _selectedAddress = description;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 14),
        ),
      );
    } catch (_) {
      // Hata durumunda şimdilik sessiz kal.
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _drawRoute(LatLng origin, LatLng destination) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: <String, dynamic>{
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'key': _googleApiKey,
        },
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data as String) as Map<String, dynamic>;

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return;

      final overviewPolyline = routes.first['overview_polyline']?['points']?.toString();
      if (overviewPolyline == null) return;

      final points = _decodePolyline(overviewPolyline);

      setState(() {
        _polylines
          ..clear()
          ..add(
            Polyline(
              polylineId: const PolylineId('route'),
              color: Colors.blueAccent,
              width: 5,
              points: points,
            ),
          );
      });
    } catch (_) {
      // Hata durumunda sessiz geç.
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (_currentLocation == null) {
      await _initCurrentLocation();
      return;
    }
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLocation!, zoom: 14),
      ),
    );
  }

  /// Geocoding API: Koordinattan insan okunur adres üret.
  Future<String?> _reverseGeocode(LatLng position) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: <String, dynamic>{
          'latlng': '${position.latitude},${position.longitude}',
          'key': _googleApiKey,
          'language': 'tr',
        },
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data as String) as Map<String, dynamic>;

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      return results.first['formatted_address']?.toString();
    } catch (_) {
      return null;
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      final double latitude = lat / 1e5;
      final double longitude = lng / 1e5;
      points.add(LatLng(latitude, longitude));
    }

    return points;
  }

  void _showOfferDialog(String listingId, String title) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Teklif ver: $title'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Teklif (TL)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () async {
                final value = double.tryParse(controller.text);
                if (value == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Geçerli bir tutar gir.')),
                  );
                  return;
                }

                // Check if user is trying to offer on their own listing
                final currentUserId = await apiClient.getCurrentUserId();
                final listing = _listings.firstWhere(
                  (item) => item['id']?.toString() == listingId,
                  orElse: () => null,
                );
                final listingOwnerId = listing?['ownerId']?.toString();

                if (currentUserId == listingOwnerId) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kendi ilanınıza teklif veremezsiniz.')),
                  );
                  return;
                }

                try {
                  await apiClient.createOffer(
                    listingId: listingId,
                    amount: value,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Teklif gönderildi.')),
                  );
                  Navigator.pop(context);
                  // Refresh listings to update the UI
                  await _loadListings();
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Teklif gönderilemedi, tekrar dene.')),
                  );
                }
              },
              child: const Text('Gönder'),
            ),
          ],
        );
      },
    );
  }

  void _openOffersSheet(String listingId, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TeklifListesiSheet(listingId: listingId, title: title),
    );
  }

  Widget _buildActionButton(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}