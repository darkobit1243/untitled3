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

  // Listings
  List<dynamic> _listings = [];
  bool _isLoading = false;

  // Google Maps state
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  String? _selectedAddress;
  LatLng? _currentLocation;
  int? _senderListingCount;
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
    return Scaffold(
      // Harita tam ekran olacak, Stack ile butonları üzerine koyacağız
      body: Stack(
        children: [
          // Katman 1: Harita
          GoogleMap(
            initialCameraPosition: _initialPosition,
            myLocationEnabled: _currentLocation != null,
            zoomControlsEnabled: false,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              // Konum daha önce alındıysa kamerayı oraya al.
              if (_currentLocation != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _currentLocation!, zoom: 12),
                  ),
                );
              }
            },
            onTap: _onMapTap,
          ),

          // Katman 2: Alt Kısımdaki Action Butonları
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                child: Row(
                  children: [
                    if (!isCarrier) ...[
                      Expanded(
                        child: _buildActionButton(
                          context,
                          icon: Icons.local_post_office_outlined,
                          label: 'Kargo\nGönder',
                          color: TrustShipColors.primaryRed,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CreateShipmentScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.directions_car,
                        label: 'Rota\nBul',
                        color: TrustShipColors.successGreen,
                        onTap: () async {
                          // Şimdilik seçili nokta ile başlangıç noktası arasında rota çiz.
                          if (_markers.isNotEmpty) {
                            final dest = _markers.last.position;
                            await _drawRoute(_initialPosition.target, dest);
                          } else {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Önce haritada bir adres seç.')),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 160,
            left: 20,
            right: 20,
            child: _buildRoleListCard(),
          ),

          // Katman 3: Üst Arama Çubuğu + adres autocomplete
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
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
                  const SizedBox(height: 12),
                  _buildRoleSummaryCard(),
                if (_placePredictions.isNotEmpty)
                  Container(
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
                  ),
              ],
            ),
          ),

          // Katman 4: Sağ altta ilan listesi kısayolu
          Positioned(
            right: 16,
            bottom: 140,
            child: FloatingActionButton.extended(
              onPressed: _openListingsBottomSheet,
              icon: const Icon(Icons.list_alt),
              label: const Text('İlanlar'),
            ),
          ),

          // Katman 5: Seçilen adres bilgi çipi (Geocoding sonucu)
          if (_selectedAddress != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 110,
              child: Container(
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
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadListings() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await apiClient.fetchListings();
      setState(() {
        _listings = data;
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
                        onPressed: listingId.isEmpty ? null : () => _showOfferDialog(listingId, title),
                        icon: const Icon(Icons.local_offer, size: 18),
                        label: const Text('Teklif ver'),
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
      subtitle = '${_senderListingCount ?? 0} ilan';
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

  Widget _buildRoleListCard() {
    final entries = widget.role == 'sender' ? _senderListings : _carrierDeliveries;
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final isSender = widget.role == 'sender';
    final title = isSender ? 'Aktif İlanlar' : 'Görevlerim';
    final subtitle = isSender ? 'Yayınlanmış ilanlar' : 'Taahhüt edilen teslimatlar';

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            ...entries.take(3).map(
              (item) {
                final label = isSender
                    ? item['title']?.toString() ?? 'İsim yok'
                    : item['listing']?['title']?.toString() ?? 'Teslimat';
                final meta = isSender
                    ? '${item['weight'] ?? '-'} kg · ${item['pickup_location']?['lat']?.toStringAsFixed(2) ?? '?'}'
                    : 'Durum: ${item['status'] ?? 'beklemede'}';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(meta, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                );
              },
            ),
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
        if (!mounted) return;
        setState(() {
          _senderListingCount = listings.length;
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