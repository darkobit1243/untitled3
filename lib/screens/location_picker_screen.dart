// lib/screens/location_picker_screen.dart
//
// Tam ekran konum seçici:
// - Üstte arama (Google Places Autocomplete)
// - Harita + mevcut konum butonu
// - Marker ile seçim
// - "Bu noktayı seç" ile geri dön

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/google_api_keys.dart';
import '../services/google_places_service.dart';
import '../services/location_gate.dart';

enum LocationPickerMarkerKind { pickup, dropoff }

class LocationResult {
  final LatLng position;
  final String description;

  LocationResult({
    required this.position,
    required this.description,
  });
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.title,
    this.initialPosition,
    required this.markerKind,
  });

  final String title;
  final LatLng? initialPosition;
  final LocationPickerMarkerKind markerKind;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final Dio _dio = Dio();
  late final GooglePlacesService _places = GooglePlacesService(_dio);
  CancelToken? _placesCancelToken;
  CancelToken? _currentLocationCancelToken;
  GoogleMapController? _mapController;

  static Future<BitmapDescriptor>? _pickupIconFuture;
  static Future<BitmapDescriptor>? _dropoffIconFuture;
  BitmapDescriptor? _markerIcon;
  LatLng? _pendingCameraTarget;
  double? _pendingCameraZoom;

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _predictions = [];
  String? _searchError;
  Timer? _debounce;
  int _predictionRequestSeq = 0;

  LatLng? _currentLocation;
  LatLng? _selectedPosition;

  final Set<Marker> _markers = {};

  static const CameraPosition _fallbackCamera = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 10,
  );

  @override
  void initState() {
    super.initState();
    _warmMarkerIcon();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCurrentLocation());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _placesCancelToken?.cancel();
    _currentLocationCancelToken?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _warmMarkerIcon() {
    const markerSize = 56.0;
    const config = ImageConfiguration(
      size: Size(markerSize, markerSize),
    );
    _pickupIconFuture ??= BitmapDescriptor.asset(
      config,
      'assets/markers/Alis_noktasi.png',
    );
    _dropoffIconFuture ??= BitmapDescriptor.asset(
      config,
      'assets/markers/Varis_noktasi.png',
    );

    final future = widget.markerKind == LocationPickerMarkerKind.pickup
        ? _pickupIconFuture!
        : _dropoffIconFuture!;

    // ignore: unawaited_futures
    future.then((icon) {
      if (!mounted) return;
      setState(() {
        _markerIcon = icon;
      });
    }).catchError((_) {
      // Fallback to default marker.
    });
  }

  MarkerId get _selectedMarkerId {
    return widget.markerKind == LocationPickerMarkerKind.pickup
        ? const MarkerId('Alis_noktasi')
        : const MarkerId('Varis_noktasi');
  }

  String get _selectedMarkerTitle {
    return widget.markerKind == LocationPickerMarkerKind.pickup ? 'Alış Noktası' : 'Varış Noktası';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Adres veya yer ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                if (_predictions.isNotEmpty) {
                  final first = _predictions.first as Map<String, dynamic>;
                  final placeId = first['place_id']?.toString();
                  final desc = first['description']?.toString() ?? '';
                  if (placeId != null) {
                    _onPlaceSelected(placeId, desc);
                  }
                }
              },
            ),
          ),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _searchError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          if (_predictions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _predictions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _predictions[index] as Map<String, dynamic>;
                    final description = item['description']?.toString() ?? '';
                    return ListTile(
                      leading:
                          const Icon(Icons.location_on_outlined, color: Colors.redAccent),
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
            ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: widget.initialPosition != null
                      ? CameraPosition(target: widget.initialPosition!, zoom: 12)
                      : _fallbackCamera,
                  markers: _markers,
                  myLocationEnabled: _currentLocation != null,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;

                    // Apply any pending camera move (e.g., current location resolved before controller ready).
                    final target = _pendingCameraTarget;
                    final zoom = _pendingCameraZoom;
                    if (target != null && zoom != null) {
                      _pendingCameraTarget = null;
                      _pendingCameraZoom = null;
                      controller.moveCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(target: target, zoom: zoom),
                        ),
                      );
                    }
                  },
                  onTap: (pos) {
                    setState(() {
                      _selectedPosition = pos;
                      _markers
                        ..clear()
                        ..add(
                          Marker(
                            markerId: _selectedMarkerId,
                            position: pos,
                            icon: _markerIcon ?? BitmapDescriptor.defaultMarker,
                            anchor: const Offset(0.5, 1.0),
                            infoWindow: InfoWindow(title: _selectedMarkerTitle),
                          ),
                        );
                    });
                  },
                ),
                Positioned(
                  right: 16,
                  top: 16,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: IconButton(
                      icon: const Icon(Icons.my_location, color: Colors.blueAccent),
                      onPressed: _goToCurrent,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: ElevatedButton.icon(
                    onPressed: _selectedPosition == null ? null : _confirmSelection,
                    icon: const Icon(Icons.check),
                    label: const Text('Bu noktayı seç'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.isEmpty) {
      setState(() {
        _predictions = [];
        _searchError = null;
      });
      return;
    }
    if (_searchError != null) {
      setState(() {
        _searchError = null;
      });
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _fetchPredictions(value);
    });
  }

  Future<void> _fetchPredictions(String input) async {
    _placesCancelToken?.cancel();
    _placesCancelToken = CancelToken();
    final requestSeq = ++_predictionRequestSeq;
    try {
      final bias = _currentLocation ?? widget.initialPosition;
      final predictions = await _places.autocomplete(
        input: input,
        location: bias,
        radiusMeters: 150000,
        strictBounds: false,
        cancelToken: _placesCancelToken,
      );
      if (!mounted) return;
      if (requestSeq != _predictionRequestSeq) return;
      setState(() {
        _predictions = predictions;
        _searchError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_placesCancelToken?.isCancelled == true) return;
      if (requestSeq != _predictionRequestSeq) return;
      setState(() {
        _predictions = [];
        if (e is GooglePlacesApiException) {
          final details = (e.message ?? '').trim();
          _searchError = details.isEmpty
              ? 'Google Places hatası: ${e.status}'
              : 'Google Places hatası: ${e.status}\n$details';
          return;
        }

        final msg = e.toString();
        if (msg.contains('Missing GOOGLE_MAPS_WEB_API_KEY')) {
          _searchError =
              'Harita araması için GOOGLE_MAPS_WEB_API_KEY eksik. (dart_defines.json / --dart-define-from-file)\n'
              'Derlenmiş değer: ${GoogleApiKeys.mapsWebApiKeyMasked}\n'
              'Not: hot restart yeni define almaz; uygulamayı durdurup tekrar çalıştır.';
        } else if (msg.contains('REQUEST_DENIED')) {
          _searchError = 'Google Places isteği reddedildi (API key/izinleri/billing kontrol).';
        } else {
          _searchError = 'Arama başarısız oldu. İnternet/izinleri kontrol et.';
        }
      });
    }
  }

  Future<void> _onPlaceSelected(String placeId, String description) async {
    final pos = await _places.placeLatLng(placeId: placeId);
    if (pos == null) return;

    setState(() {
      _selectedPosition = pos;
      _predictions = [];
      _searchController.text = description;
      _markers
        ..clear()
        ..add(
          Marker(
            markerId: _selectedMarkerId,
            position: pos,
            icon: _markerIcon ?? BitmapDescriptor.defaultMarker,
            anchor: const Offset(0.5, 1.0),
            infoWindow: InfoWindow(title: description),
          ),
        );
    });

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: pos, zoom: 14),
      ),
    );
  }

  Future<void> _initCurrentLocation({bool userInitiated = false}) async {
    try {
      _currentLocationCancelToken?.cancel();
      _currentLocationCancelToken = CancelToken();
      final ok = await LocationGate.ensureReady(
        context: context,
        userInitiated: userInitiated,
      );
      if (!ok) return;

      await _setLastKnownLocation();

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });

      final target = _currentLocation;
      if (target == null) return;
      if (_mapController == null) {
        _pendingCameraTarget = target;
        _pendingCameraZoom = 13;
        return;
      }
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 13),
        ),
      );
    } catch (_) {
      // Sessiz geç
    }
  }

  Future<void> _setLastKnownLocation() async {
    if (_currentLocation != null) return;
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) return;
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(last.latitude, last.longitude);
      });

      final target = _currentLocation;
      if (target == null) return;
      if (_mapController == null) {
        _pendingCameraTarget = target;
        _pendingCameraZoom = 13;
        return;
      }
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 13),
        ),
      );
    } catch (_) {
      // Sessiz geç
    }
  }

  Future<void> _goToCurrent() async {
    if (_currentLocation == null) {
      await _ensureCurrentLocation(userInitiated: true);
    }
    if (_currentLocation != null) {
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 14),
        ),
      );
    }
  }

  Future<void> _ensureCurrentLocation({bool userInitiated = false}) async {
    if (_currentLocation != null) return;
    final ok = await LocationGate.ensureReady(
      context: context,
      userInitiated: userInitiated,
    );
    if (!ok) return;
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(last.latitude, last.longitude);
      });
      final target = _currentLocation;
      if (target == null) return;
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 12),
        ),
      );
      return;
    }
    await _initCurrentLocation(userInitiated: userInitiated);
  }

  void _confirmSelection() {
    if (_selectedPosition == null) return;
    final desc = _searchController.text.isEmpty
        ? 'Seçilen konum'
        : _searchController.text;
    Navigator.pop(
      context,
      LocationResult(position: _selectedPosition!, description: desc),
    );
  }
}


