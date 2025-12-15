import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/api_client.dart';
import '../theme/trustship_theme.dart';
import '../widgets/Home_screen_widgets/home_screen_widgets.dart';
import 'ilanlar_screen.dart';
import 'teklif_listesi_sheet.dart';
import 'package:untitled/screens/home_common.dart';

class CarrierHomeScreen extends StatefulWidget {
  const CarrierHomeScreen({super.key});

  @override
  State<CarrierHomeScreen> createState() => _CarrierHomeScreenState();
}

class _CarrierHomeScreenState extends State<CarrierHomeScreen> {
  final Dio _dio = Dio();
  CancelToken? _placesCancelToken;

  // Listings
  List<dynamic> _listings = [];
  List<Map<String, dynamic>> _nearestListings = [];

  String? _selectedAddress;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  BitmapDescriptor? _currentLocationIcon;
  BitmapDescriptor? _listingIcon;
  LatLng? _currentLocation;

  // Places autocomplete state
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _placePredictions = [];
  Timer? _debounce;

  static const CameraPosition _initialPosition = CameraPosition(target: LatLng(41.0082, 28.9784), zoom: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCurrentLocation();
      _prepareMarkerIcons();
      // ignore: unawaited_futures
      _loadListings();
    });
  }

  Future<void> _prepareMarkerIcons() async {
    try {
      final curr = await createSmallLocationMarkerBitmapDescriptor(color: const Color(0xFF2196F3));
      final list = await createCargoBoxMarkerBitmapDescriptor(const Color(0xFFFF9800));
      if (mounted) {
        setState(() {
          _currentLocationIcon = curr;
          _listingIcon = list;
        });
      }
    } catch (_) {}
  }

  // marker bitmap creation moved to home_common.createMarkerBitmapDescriptor

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildCarrierBody(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Future<void> _loadListings() async {
    try {
      final data = await apiClient.fetchListings();
      final nearest = await _getNearestListings();
      if (!mounted) return;
      setState(() {
        _listings = data;
        _nearestListings = nearest;
      });
      if (mounted) _updateListingMarkers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İlanlar alınamadı, bağlantını kontrol et.')));
    }
  }

  Future<List<Map<String, dynamic>>> _getNearestListings() async {
    if (_currentLocation == null || _listings.isEmpty) return [];
    final current = _currentLocation!;
    final currentUserId = await apiClient.getCurrentUserId();
    final list = List<Map<String, dynamic>>.from(_listings.cast<Map<String, dynamic>>())
        .where((item) => item['ownerId']?.toString() != currentUserId)
        .toList();
    list.sort((a, b) => _distanceToListing(a, current).compareTo(_distanceToListing(b, current)));
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

  Future<void> _onMapTap(LatLng position) async {
    setState(() {
      final hasTap = _markers.any((m) => m.markerId.value == 'tap_place');
      _markers.removeWhere((m) => m.markerId.value == 'tap_place');
      if (!hasTap) {
        _markers.add(Marker(
          markerId: const MarkerId('tap_place'),
          position: position,
          icon: _currentLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          onTap: () {
          if (!mounted) return;
          setState(() {
            _markers.removeWhere((m) => m.markerId.value == 'tap_place');
          });
          },
        ));
      }
      _polylines.clear();
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.isEmpty) {
      setState(() => _placePredictions = []);
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
      final params = <String, dynamic>{'input': input, 'key': 'AIzaSyBJu0tWf3dKoJV6m5r_tp02sOYSOUpgCV0', 'language': 'tr', 'components': 'country:tr'};
      if (_currentLocation != null) {
        params['location'] = '${_currentLocation!.latitude},${_currentLocation!.longitude}';
        params['radius'] = 50000;
        params['strictbounds'] = 'true';
      }
      final response = await _dio.get('https://maps.googleapis.com/maps/api/place/autocomplete/json', queryParameters: params, cancelToken: _placesCancelToken);
      final data = response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : jsonDecode(response.data as String) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _placePredictions = (data['predictions'] as List<dynamic>? ?? []));
    } catch (_) {}
  }

  Future<void> _initCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 5));
      final latLng = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _currentLocation = latLng);
      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'current_location');
        _markers.add(Marker(markerId: const MarkerId('current_location'), position: latLng, icon: _currentLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), infoWindow: const InfoWindow(title: 'Konumunuz')));
      });
      _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: 12)));
    } catch (_) {}
  }

  // Route drawing intentionally omitted for now.

  void _updateListingMarkers() {
    try {
      setState(() {
        _markers.removeWhere((m) => m.markerId.value.startsWith('listing_'));
        for (final raw in _listings) {
          if (raw is! Map<String, dynamic>) continue;
          final pickup = raw['pickup_location'] as Map<String, dynamic>?;
          final id = raw['id']?.toString();
          final title = raw['title']?.toString() ?? 'İlan';
          if (pickup == null || id == null) continue;
          final lat = (pickup['lat'] as num?)?.toDouble();
          final lng = (pickup['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          final markerId = MarkerId('listing_$id');
          final listingTitle = title;
          _markers.add(Marker(markerId: markerId, position: LatLng(lat, lng), icon: _listingIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange), infoWindow: InfoWindow(title: listingTitle, snippet: 'Detay & Teklif', onTap: () => _showListingDetailsForCarrier(raw))));
        }
      });
    } catch (_) {}
  }

  Future<void> _showOfferDialog(String listingId, String title) async {
    final amountController = TextEditingController();
    await showDialog(context: context, builder: (ctx) {
      return AlertDialog(title: Text('Teklif Ver - $title'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Teklif tutarı (₺)'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')), ElevatedButton(onPressed: () {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teklif gönderildi')));
      }, child: const Text('Gönder'))]);
    });
  }

  void _showListingDetailsForCarrier(Map<String, dynamic> listing) {
    final listingId = listing['id']?.toString() ?? '';
    final title = listing['title']?.toString() ?? 'İlan';
    final desc = listing['description']?.toString() ?? '';
    final pickup = listing['pickup_location'] as Map<String, dynamic>?;
    final pickupStr = pickup != null ? '${pickup['lat']}, ${pickup['lng']}' : 'Bilinmiyor';
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: 0.6,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(title, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))), IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close))]),
              const SizedBox(height: 8),
              Text(desc, style: const TextStyle(color: Colors.black87)),
              const SizedBox(height: 12),
              Text('Alış noktası: $pickupStr', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              FutureBuilder<dynamic>(future: () async {
                final ownerId = listing['ownerId']?.toString();
                if (ownerId == null || ownerId.isEmpty) return {};
                try {
                  return await apiClient.fetchUserById(ownerId);
                } catch (_) {
                  return {};
                }
              }(), builder: (context, snap) {
                final owner = snap.data ?? {};
                final ownerName = owner['fullName']?.toString() ?? owner['email']?.toString() ?? 'Gönderici';
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Gönderici: $ownerName', style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 6), Row(children: [ElevatedButton(onPressed: () {Navigator.pop(ctx); _showOfferDialog(listingId, title);}, child: const Text('Teklif Ver')), const SizedBox(width: 8), OutlinedButton(onPressed: () async {Navigator.pop(ctx); await _openOffersSheet(listingId, title);}, child: const Text('Teklifleri Gör'))])]);
              })
            ]),
          ),
        ),
      );
    });
  }

  Future<void> _goToCurrentLocation() async {
    if (_currentLocation == null) {
      await _initCurrentLocation();
      return;
    }
    _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _currentLocation!, zoom: 14)));
  }

  Future<void> _openOffersSheet(String listingId, String title) async {
    await showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), builder: (_) => TeklifListesiSheet(listingId: listingId, title: title));
    _loadListings();
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
        if (_nearestListings.isNotEmpty)
          Positioned(
            bottom: 150,
            left: 20,
            right: 20,
            child: NearbyListings(
              listings: _nearestListings,
              onClose: () {},
              onDetailsPressed: (item) {},
              onOfferPressed: (item) async {
                final currentUserId = await apiClient.getCurrentUserId();
                final listingOwnerId = item['ownerId']?.toString();
                if (currentUserId == listingOwnerId) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kendi ilanınıza teklif veremezsiniz.')));
                  return;
                }
                _showOfferDialog(item['id']?.toString() ?? '', item['title']?.toString() ?? '');
              },
            ),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                onPressed: _goToCurrentLocation,
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: TrustShipColors.primaryRed),
              ),
              const SizedBox(height: 10),
              FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const IlanlarScreen()));
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
            child: SelectedAddressChip(address: _selectedAddress!),
          ),
      ],
    );
  }

  Widget _buildSearchAndSummaryCard(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [RoleSummaryCard(role: 'carrier', isLoading: false, error: null, senderListingCount: null, senderPendingOffers: null, carrierDeliveryCount: null), const SizedBox(height: 12), Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.search, color: Colors.grey), const SizedBox(width: 10), Expanded(child: TextField(controller: _searchController, decoration: const InputDecoration(hintText: 'Adres veya yer ara...', border: InputBorder.none), onChanged: _onSearchChanged))]))]));

  }

  Widget _buildPredictionList() {
    return PredictionList(placePredictions: _placePredictions, onPlaceSelected: (placeId, description) => _onPlaceSelected(placeId, description));
  }

  Future<void> _onPlaceSelected(String placeId, String description) async {
    try {
      final response = await _dio.get('https://maps.googleapis.com/maps/api/place/details/json', queryParameters: <String, dynamic>{'place_id': placeId, 'key': 'AIzaSyBJu0tWf3dKoJV6m5r_tp02sOYSOUpgCV0', 'fields': 'geometry/location'});
      final data = response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : jsonDecode(response.data as String) as Map<String, dynamic>;
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
              icon: _currentLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(title: description),
            ),
          );
      });
      await _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 14)));
    } catch (_) {}
  }

}
