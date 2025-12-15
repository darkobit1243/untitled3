import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/api_client.dart';
import '../theme/trustship_theme.dart';
import '../widgets/Home_screen_widgets/home_screen_widgets.dart';
import 'create_shipment_screen.dart';
import 'teklif_listesi_sheet.dart';
import 'home_common.dart';

class SenderHomeScreen extends StatefulWidget {
  const SenderHomeScreen({super.key});

  @override
  State<SenderHomeScreen> createState() => _SenderHomeScreenState();
}

class _SenderHomeScreenState extends State<SenderHomeScreen> {
  final Dio _dio = Dio();
  CancelToken? _placesCancelToken;

  // Listings
  List<dynamic> _listings = [];

  // Google Maps state
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
    return Scaffold(backgroundColor: Colors.white, body: _buildSenderBody(context), floatingActionButton: _buildSenderFab(), floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked);
  }

  Future<void> _loadListings() async {
    try {
      final data = await apiClient.fetchMyListings();
      if (!mounted) return;
      setState(() {
        _listings = data;
      });
      if (mounted) _updateListingMarkers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İlanlar alınamadı, bağlantını kontrol et.')));
    }
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

  // route drawing intentionally omitted for now (kept minimal)

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
          final listingId = id;
          final listingTitle = title;
          _markers.add(Marker(markerId: markerId, position: LatLng(lat, lng), icon: _listingIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange), infoWindow: InfoWindow(title: listingTitle, snippet: 'Kargonu gör', onTap: () { _openOffersSheet(listingId, listingTitle); })));
        }
      });
    } catch (_) {}
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

  Widget _buildSenderBody(BuildContext context) {
    return Stack(children: [GoogleMap(initialCameraPosition: _initialPosition, markers: _markers, polylines: _polylines, zoomControlsEnabled: false, myLocationEnabled: _currentLocation != null, onMapCreated: (controller) => _mapController = controller, onTap: _onMapTap), Positioned(top: 40, left: 20, right: 20, child: Column(children: [_buildSearchAndSummaryCard(context), if (_placePredictions.isNotEmpty) const SizedBox(height: 8), if (_placePredictions.isNotEmpty) _buildPredictionList()])), if (_selectedAddress != null) Positioned(bottom: 140, left: 20, right: 20, child: SelectedAddressChip(address: _selectedAddress!)), Positioned(bottom: 24, right: 16, child: FloatingActionButton(onPressed: _goToCurrentLocation, backgroundColor: Colors.white, child: const Icon(Icons.my_location, color: TrustShipColors.primaryRed))),]);
  }

  Widget _buildSearchAndSummaryCard(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [RoleSummaryCard(role: 'sender', isLoading: false, error: null, senderListingCount: null, senderPendingOffers: null, carrierDeliveryCount: null), const SizedBox(height: 12), Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.search, color: Colors.grey), const SizedBox(width: 10), Expanded(child: TextField(controller: _searchController, decoration: const InputDecoration(hintText: 'Adres veya yer ara...', border: InputBorder.none), onChanged: _onSearchChanged))]))]));

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
        _markers..clear()..add(Marker(markerId: const MarkerId('selected_place'), position: target, infoWindow: InfoWindow(title: description)));
      });
      await _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 14)));
    } catch (_) {}
  }

  Future<String?> _reverseGeocode(LatLng position) async {
    try {
      final response = await _dio.get('https://maps.googleapis.com/maps/api/geocode/json', queryParameters: <String, dynamic>{'latlng': '${position.latitude},${position.longitude}', 'key': 'AIzaSyBJu0tWf3dKoJV6m5r_tp02sOYSOUpgCV0', 'language': 'tr'});
      final data = response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : jsonDecode(response.data as String) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;
      return results.first['formatted_address']?.toString();
    } catch (_) { return null; }
  }

  Widget _buildSenderFab() {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateShipmentScreen()));
      },
      backgroundColor: TrustShipColors.primaryBlue,
      icon: const Icon(Icons.add),
      label: const Text('Yeni Kargo Gönder'),
    );
  }

  String? _selectedAddress;

}
