import 'dart:async';
import 'dart:convert';
import 'dart:io';
// import 'dart:math' as math; // Unused, removed

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Used for provider definition only
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../services/google_api_keys.dart';

// --- State Class ---
class CreateShipmentState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  // Form Fields Data
  final XFile? pickedImage;
  final LatLng? pickupLocation;
  final String? pickupAddress;
  final LatLng? dropoffLocation;
  final String? dropoffAddress;

  // Map Data
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final LatLng? currentLocation;

  CreateShipmentState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
    this.pickedImage,
    this.pickupLocation,
    this.pickupAddress,
    this.dropoffLocation,
    this.dropoffAddress,
    this.markers = const {},
    this.polylines = const {},
    this.currentLocation,
  });

  CreateShipmentState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    XFile? pickedImage,
    LatLng? pickupLocation,
    String? pickupAddress,
    LatLng? dropoffLocation,
    String? dropoffAddress,
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    LatLng? currentLocation,
  }) {
    return CreateShipmentState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // Reset error on new state unless explicitly passed (logic choice)
      isSuccess: isSuccess ?? this.isSuccess,
      pickedImage: pickedImage ?? this.pickedImage,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      currentLocation: currentLocation ?? this.currentLocation,
    );
  }
}

// --- Notifier Class ---
class CreateShipmentNotifier extends StateNotifier<CreateShipmentState> {
  CreateShipmentNotifier() : super(CreateShipmentState());

  final Dio _dio = Dio();
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;

  // Init logic (load icons etc)
  Future<void> init(BuildContext context) async {
    // Icons loading could be done here or passed in. 
    // For simplicity, we assume assets are moved here or loaded.
    // Actually, loading assets requires context or rootBundle.
    // We'll skip custom icon loading inside the provider to keep it pure,
    // or we can do it once.
  }

  void setIcons(BitmapDescriptor? pickup, BitmapDescriptor? dropoff) {
    _pickupIcon = pickup;
    _dropoffIcon = dropoff;
    _updateMarkers();
  }

  void setCurrentLocation(LatLng loc) {
    state = state.copyWith(currentLocation: loc);
    _updateMarkers();
  }

  void setImage(XFile? image) {
    state = state.copyWith(pickedImage: image);
  }

  void setPickup(LatLng pos, String address) {
    state = state.copyWith(pickupLocation: pos, pickupAddress: address);
    _updateMarkers();
    _fetchRoute();
  }

  void setDropoff(LatLng pos, String address) {
    state = state.copyWith(dropoffLocation: pos, dropoffAddress: address);
    _updateMarkers();
    _fetchRoute();
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    if (state.currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: state.currentLocation!,
          infoWindow: const InfoWindow(title: 'Mevcut Konum'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    if (state.pickupLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: state.pickupLocation!,
          infoWindow: InfoWindow(title: 'Alış: ${state.pickupAddress ?? ""}'),
          icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }

    if (state.dropoffLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: state.dropoffLocation!,
          infoWindow: InfoWindow(title: 'Teslim: ${state.dropoffAddress ?? ""}'),
          icon: _dropoffIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    state = state.copyWith(markers: markers);
  }

  Future<void> _fetchRoute() async {
    if (state.pickupLocation == null || state.dropoffLocation == null) {
      state = state.copyWith(polylines: {});
      return;
    }

    try {
      if (GoogleApiKeys.mapsWebApiKey.isEmpty) return;

      final origin = state.pickupLocation!;
      final dest = state.dropoffLocation!;

      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: <String, dynamic>{
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${dest.latitude},${dest.longitude}',
          'key': GoogleApiKeys.mapsWebApiKey,
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

      final polyline = Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.blueAccent,
        width: 5,
        points: points,
      );

      state =   state.copyWith(polylines: {polyline});
    } catch (_) {
      // Ignore route errors
    }
  }

  Future<void> submitListing({
    required String title,
    required String description,
    required double weight,
    required String receiverPhone,
  }) async {
    if (state.isLoading) return;

    if (state.pickedImage == null) {
      state = state.copyWith(errorMessage: 'Fotoğraf eklemeden devam edemezsiniz.');
      return;
    }
    if (state.pickupLocation == null || state.dropoffLocation == null) {
      state = state.copyWith(errorMessage: 'Lütfen haritadan alış ve teslim noktalarını seç.');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final photoDataUrl = await _buildPickedImageDataUrl(state.pickedImage!);
      
      await apiClient.createListing(
        title: title,
        description: description,
        photoDataUrl: photoDataUrl,
        weight: weight,
        receiverPhone: receiverPhone,
        pickupLat: state.pickupLocation!.latitude,
        pickupLng: state.pickupLocation!.longitude,
        dropoffLat: state.dropoffLocation!.latitude,
        dropoffLng: state.dropoffLocation!.longitude,
      );

      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      var msg = e.toString().replaceAll('Exception: ', '').trim();
      if (msg.startsWith('İlan oluşturulamadı:')) {
        msg = msg.replaceFirst('İlan oluşturulamadı:', '').trim();
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }

  // --- Helpers ---

  Future<String> _buildPickedImageDataUrl(XFile picked) async {
    final bytes = await File(picked.path).readAsBytes();
    final b64 = base64Encode(bytes);
    final mime = _inferMimeTypeFromPath(picked.path);
    return 'data:$mime;base64,$b64';
  }

  String _inferMimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
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
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}

// --- Provider Definition ---
final createShipmentProvider = StateNotifierProvider.autoDispose<CreateShipmentNotifier, CreateShipmentState>(
  (ref) => CreateShipmentNotifier(),
);
