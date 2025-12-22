import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/api_client.dart';
import '../../services/google_places_service.dart';
import '../../services/location_gate.dart';
import '../../theme/bitasi_theme.dart';
import '../../widgets/Home_screen_widgets/home_screen_widgets.dart';
import 'ilanlar_screen.dart';
import '../home_common.dart';
import '../offer_amount_screen.dart';

class CarrierHomeScreen extends StatefulWidget {
  const CarrierHomeScreen({super.key});

  @override
  State<CarrierHomeScreen> createState() => _CarrierHomeScreenState();
}

class _CarrierHomeScreenState extends State<CarrierHomeScreen> with TickerProviderStateMixin {
  final Dio _dio = Dio();
  late final GooglePlacesService _places = GooglePlacesService(_dio);
  CancelToken? _placesCancelToken;

  // Listings
  List<dynamic> _listings = [];

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

  CameraPosition _lastCameraPosition = _initialPosition;

  @override
  void initState() {
    super.initState();
    // Prepare marker icons ASAP so custom cargo pin shows quickly.
    // ignore: unawaited_futures
    _prepareMarkerIcons();
    // Fetch listings ASAP; cache also helps other screens (İlanlar, Messages, etc.).
    // ignore: unawaited_futures
    _loadListings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCurrentLocation();
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
      body: _buildCarrierBody(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Future<void> _loadListings() async {
    try {
      final data = await apiClient.fetchListings();
      if (!mounted) return;
      setState(() {
        _listings = data;
      });
      if (mounted) _updateListingMarkers();
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(const SnackBar(content: Text('İlanlar alınamadı, bağlantını kontrol et.')));
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

  // Route drawing intentionally omitted for now.

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
        final markerId = MarkerId('listing_$id');
        final listingTitle = title;
        listingMarkers.add(
          Marker(
            markerId: markerId,
            position: LatLng(lat, lng),
            icon: _listingIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            onTap: () => _showListingDetailsForCarrier(raw),
            infoWindow: InfoWindow(
              title: listingTitle,
              snippet: 'Detay & Teklif Ver',
              onTap: () => _showListingDetailsForCarrier(raw),
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

  Future<void> _goToCurrentLocation() async {
    final cached = _currentLocation;
    if (cached != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: cached, zoom: 14),
        ),
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

  Future<void> _showOfferDialog(String listingId, String title) async {
    if (listingId.isEmpty) return;

    final result = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        pageBuilder: (_, __, ___) => OfferAmountScreen(title: title),
        maintainState: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (!mounted) return;

    if (result == null || result.trim().isEmpty) return;

    final normalized = result.trim().replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir tutar girin.')),
      );
      return;
    }

    try {
      await apiClient.createOffer(listingId: listingId, amount: value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teklif gönderildi.')),
      );
      // Refresh listings/markers (listing may disappear after acceptance).
      // ignore: unawaited_futures
      _loadListings();
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.contains('zaten kabul edilmiş')
          ? 'Bu ilan için teklif kabul edilmiş. Artık teklif verilemez.'
          : raw;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teklif gönderilemedi: $msg')),
      );
      // ignore: unawaited_futures
      _loadListings();
    }
  }

  void _showListingDetailsForCarrier(Map<String, dynamic> listing) {
    final listingId = listing['id']?.toString() ?? '';
    final title = listing['title']?.toString() ?? 'İlan';
    final desc = listing['description']?.toString() ?? '';
    final pickup = listing['pickup_location'] as Map<String, dynamic>?;
    final pickupStr = pickup != null ? '${pickup['lat']}, ${pickup['lng']}' : 'Bilinmiyor';
    final ownerName = listing['ownerName']?.toString() ?? listing['ownerEmail']?.toString() ?? 'Gönderici';
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
              Text('Gönderici: $ownerName', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showOfferDialog(listingId, title);
                      },
                      child: const Text('Teklif Ver'),
                    ),
                  ),
                ],
              )
            ]),
          ),
        ),
      );
    });
  }

  Widget _buildCarrierBody() {
    return Stack(
      children: [
        GoogleMap(
          key: const ValueKey('carrier_map'),
          initialCameraPosition: _lastCameraPosition,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          markers: _markers,
          polylines: _polylines,
          onMapCreated: (controller) => _mapController = controller,
          onCameraMove: (pos) {
            _lastCameraPosition = pos;
          },
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
        Positioned(
          bottom: 24,
          left: 16,
          child: FloatingActionButton(
            heroTag: 'carrier_my_location_fab',
            onPressed: _goToCurrentLocation,
            backgroundColor: Colors.white,
            child: const Icon(Icons.my_location, color: BiTasiColors.primaryRed),
          ),
        ),
        Positioned(
          bottom: 24,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'carrier_listings_fab',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const IlanlarScreen()));
            },
            backgroundColor: Colors.white,
            foregroundColor: BiTasiColors.primaryRed,
            icon: const Icon(Icons.list_alt),
            label: const Text('İlanlar'),
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
            icon: _currentLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(title: description),
          ),
        );
    });
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 14)),
    );
  }

}
