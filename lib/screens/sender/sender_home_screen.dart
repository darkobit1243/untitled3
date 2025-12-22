import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/api_client.dart';
import '../../services/google_places_service.dart';
import '../../services/location_label_cache.dart';
import '../../services/location_gate.dart';
import '../../theme/bitasi_theme.dart';
import '../../widgets/Home_screen_widgets/home_screen_widgets.dart';
import '../create_shipment_screen.dart';
import '../home_common.dart';
import 'teklif_listesi_sheet.dart';

class SenderHomeScreen extends StatefulWidget {
  const SenderHomeScreen({super.key});

  @override
  State<SenderHomeScreen> createState() => _SenderHomeScreenState();
}

class _SenderHomeScreenState extends State<SenderHomeScreen> {
  final Dio _dio = Dio();
  late final GooglePlacesService _places = GooglePlacesService(_dio);
  CancelToken? _placesCancelToken;

  final Map<String, String> _listingPickupLabels = {};
  final Set<String> _listingPickupLabelInFlight = {};

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
      final list = await createCargoPinMarkerBitmapDescriptor(size: 86, fallbackColor: const Color(0xFFFF9800));
      if (mounted) {
        setState(() {
          _currentLocationIcon = curr;
          _listingIcon = list;
        });

        // Repaint existing markers with the newly loaded custom icons.
        if (_listings.isNotEmpty) {
          _updateListingMarkers();
        }
        final loc = _currentLocation;
        if (loc != null) {
          setState(() {
            _markers.removeWhere((m) => m.markerId.value == 'current_location');
            _markers.add(
              Marker(
                markerId: const MarkerId('current_location'),
                position: loc,
                icon: _currentLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                infoWindow: const InfoWindow(title: 'Konumunuz'),
              ),
            );
          });
        }
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
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: _buildSenderBody(context),
      floatingActionButton: _buildSenderFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İlanlar alınamadı, bağlantını kontrol et.')));
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
    _placesCancelToken?.cancel();
    _placesCancelToken = CancelToken();
    try {
      final predictions = await _places.autocomplete(
        input: input,
        location: _currentLocation,
        types: 'geocode',
        cancelToken: _placesCancelToken,
      );
      if (!mounted) return;
      setState(() => _placePredictions = predictions);
    } catch (_) {
      if (!mounted) return;
      if (_placesCancelToken?.isCancelled == true) return;
      setState(() => _placePredictions = []);
    }
  }

  Future<void> _initCurrentLocation({bool userInitiated = false}) async {
    try {
      final ok = await LocationGate.ensureReady(
        context: context,
        userInitiated: userInitiated,
      );
      if (!ok) return;
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
      final listingMarkers = <Marker>[];
      for (final raw in _listings) {
        if (raw is! Map<String, dynamic>) continue;
        final pickup = raw['pickup_location'] as Map<String, dynamic>?;
        final id = raw['id']?.toString();
        final title = raw['title']?.toString() ?? 'İlan';
        if (pickup == null || id == null) continue;
        final lat = (pickup['lat'] as num?)?.toDouble();
        final lng = (pickup['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final cachedLabel = _listingPickupLabels[id];
        if (cachedLabel == null && !_listingPickupLabelInFlight.contains(id)) {
          // ignore: unawaited_futures
          _ensureListingPickupLabel(listingId: id, position: LatLng(lat, lng));
        }

        final markerId = MarkerId('listing_$id');
        final listingId = id;
        final listingTitle = title;
        listingMarkers.add(
          Marker(
            markerId: markerId,
            position: LatLng(lat, lng),
            icon: _listingIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: listingTitle,
              snippet: cachedLabel ?? 'Adres alınıyor…',
              onTap: () {
                _openOffersSheet(listingId, listingTitle);
              },
            ),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _markers.removeWhere((m) => m.markerId.value.startsWith('listing_'));
        _markers.addAll(listingMarkers);
      });
    } catch (_) {}
  }

  Future<void> _ensureListingPickupLabel({required String listingId, required LatLng position}) async {
    if (_listingPickupLabels.containsKey(listingId)) return;
    if (_listingPickupLabelInFlight.contains(listingId)) return;

    _listingPickupLabelInFlight.add(listingId);
    try {
      final cached = await LocationLabelCache.getLabel(lat: position.latitude, lng: position.longitude);
      if (!mounted) return;
      if (cached != null && cached.trim().isNotEmpty) {
        setState(() {
          _listingPickupLabels[listingId] = cached;
        });
        _updateListingMarkers();
        return;
      }

      final parts = await _places.reverseGeocodeParts(position: position);
      final label = parts?.toDisplayString() ?? await _places.reverseGeocode(position: position) ?? '';
      if (!mounted) return;
      if (label.trim().isEmpty) return;

      // Persist across restarts.
      // ignore: unawaited_futures
      LocationLabelCache.setLabel(lat: position.latitude, lng: position.longitude, label: label);

      setState(() {
        _listingPickupLabels[listingId] = label;
      });
      // Refresh marker snippets with the new label.
      _updateListingMarkers();
    } catch (_) {
      // ignore
    } finally {
      _listingPickupLabelInFlight.remove(listingId);
    }
  }

  Future<void> _goToCurrentLocation() async {
    final cached = _currentLocation;
    if (cached != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: cached, zoom: 14)),
      );
      // Refresh in the background for better accuracy.
      // ignore: unawaited_futures
      _initCurrentLocation(userInitiated: true);
      return;
    }

    // No cached location yet: try last-known first (fast), then refresh.
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        final latLng = LatLng(last.latitude, last.longitude);
        setState(() => _currentLocation = latLng);
        setState(() {
          _markers.removeWhere((m) => m.markerId.value == 'current_location');
          _markers.add(
            Marker(
              markerId: const MarkerId('current_location'),
              position: latLng,
              icon: _currentLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: const InfoWindow(title: 'Konumunuz'),
            ),
          );
        });
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: 14)),
        );
      }
    } catch (_) {}

    await _initCurrentLocation(userInitiated: true);
  }

  Future<void> _openOffersSheet(String listingId, String title) async {
    await showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), builder: (_) => TeklifListesiSheet(listingId: listingId, title: title));
    _loadListings();
  }

  Widget _buildSenderBody(BuildContext context) {
    return Stack(children: [GoogleMap(initialCameraPosition: _initialPosition, markers: _markers, polylines: _polylines, zoomControlsEnabled: false, myLocationEnabled: false, myLocationButtonEnabled: false, onMapCreated: (controller) => _mapController = controller), Positioned(top: 40, left: 20, right: 20, child: Column(children: [_buildSearchAndSummaryCard(context), if (_placePredictions.isNotEmpty) const SizedBox(height: 8), if (_placePredictions.isNotEmpty) _buildPredictionList()])), if (_selectedAddress != null) Positioned(bottom: 140, left: 20, right: 20, child: SelectedAddressChip(address: _selectedAddress!)), Positioned(bottom: 24, right: 16, child: FloatingActionButton(heroTag: 'sender_my_location_fab', onPressed: _goToCurrentLocation, backgroundColor: Colors.white, child: const Icon(Icons.my_location, color: BiTasiColors.primaryRed))),]);
  }

  Widget _buildSearchAndSummaryCard(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [RoleSummaryCard(role: 'sender', isLoading: false, error: null, senderListingCount: null, senderPendingOffers: null, carrierDeliveryCount: null), const SizedBox(height: 12), Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.search, color: Colors.grey), const SizedBox(width: 10), Expanded(child: TextField(controller: _searchController, decoration: const InputDecoration(hintText: 'Adres veya yer ara...', border: InputBorder.none), onChanged: _onSearchChanged))]))]));

  }

  Widget _buildPredictionList() {
    return PredictionList(placePredictions: _placePredictions, onPlaceSelected: (placeId, description) => _onPlaceSelected(placeId, description));
  }

  Future<void> _onPlaceSelected(String placeId, String description) async {
    final target = await _places.placeLatLng(placeId: placeId);
    if (target == null) return;

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
    });
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 14)),
    );
  }

  Widget _buildSenderFab() {
    return FloatingActionButton.extended(
      heroTag: 'sender_create_shipment_fab',
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateShipmentScreen()));
      },
      backgroundColor: Colors.white,
      foregroundColor: BiTasiColors.primaryRed,
      icon: const Icon(Icons.add),
      label: const Text('Yeni Kargo Gönder'),
    );
  }

  String? _selectedAddress;
}
