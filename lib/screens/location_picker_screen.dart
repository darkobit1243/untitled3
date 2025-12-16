// lib/screens/location_picker_screen.dart
//
// Tam ekran konum seçici:
// - Üstte arama (Google Places Autocomplete)
// - Harita + mevcut konum butonu
// - Marker ile seçim
// - "Bu noktayı seç" ile geri dön

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/google_api_keys.dart';
import '../services/location_gate.dart';

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
  });

  final String title;
  final LatLng? initialPosition;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final Dio _dio = Dio();
  CancelToken? _placesCancelToken;
  CancelToken? _currentLocationCancelToken;
  GoogleMapController? _mapController;

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _predictions = [];
  Timer? _debounce;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCurrentLocation());
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
                  },
                  onTap: (pos) {
                    setState(() {
                      _selectedPosition = pos;
                      _markers
                        ..clear()
                        ..add(
                          Marker(
                            markerId: const MarkerId('selected'),
                            position: pos,
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
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _fetchPredictions(value);
    });
  }

  Future<void> _fetchPredictions(String input) async {
    try {
      _placesCancelToken?.cancel();
      _placesCancelToken = CancelToken();
      final params = <String, dynamic>{
        'input': input,
        'key': GoogleApiKeys.mapsWebApiKey,
        'language': 'tr',
        'components': 'country:tr',
      };

      // Kullanıcının konumuna yakın sonuçları öne çıkar.
      // strictbounds: radius dışındaki sonuçları bastırır (Samsun'dayken Adapazarı göstermesin gibi)
      if (_currentLocation != null) {
        params['location'] = '${_currentLocation!.latitude},${_currentLocation!.longitude}';
        params['radius'] = 50000; // 50km
        params['strictbounds'] = 'true';
      }

      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: params,
        cancelToken: _placesCancelToken,
      );
      final data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : jsonDecode(res.data as String) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _predictions = data['predictions'] as List<dynamic>? ?? [];
      });
    } catch (_) {
      // Sessiz geç
    }
  }

  Future<void> _onPlaceSelected(String placeId, String description) async {
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: <String, dynamic>{
          'place_id': placeId,
          'key': GoogleApiKeys.mapsWebApiKey,
          'fields': 'geometry/location',
        },
      );
      final data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : jsonDecode(res.data as String) as Map<String, dynamic>;

      final loc =
          (data['result']?['geometry']?['location']) as Map<String, dynamic>?;
      if (loc == null) return;

      final pos = LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );

      setState(() {
        _selectedPosition = pos;
        _predictions = [];
        _searchController.text = description;
        _markers
          ..clear()
          ..add(
            Marker(
              markerId: const MarkerId('selected'),
              position: pos,
              infoWindow: InfoWindow(title: description),
            ),
          );
      });

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: pos, zoom: 14),
        ),
      );
    } catch (_) {
      // Sessiz geç
    }
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
      _currentLocation = LatLng(pos.latitude, pos.longitude);

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 13),
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
      _currentLocation = LatLng(last.latitude, last.longitude);
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 13),
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
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      _currentLocation = LatLng(last.latitude, last.longitude);
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 12),
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


