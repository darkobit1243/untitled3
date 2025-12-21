import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/api_client.dart';
import '../theme/bitasi_theme.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  Map<String, dynamic>? _delivery;
  bool _loading = true;
  GoogleMapController? _controller;
  Timer? _poll;
  BitmapDescriptor? _carrierIcon;

  static const String _kCarrierMarkerAssetPath = 'assets/markers/kamyon_marker.png';

  @override
  void initState() {
    super.initState();
    _loadCarrierMarkerIcon();
    _load();
    apiClient.followDeliveryUpdates(widget.deliveryId, _handleDeliveryUpdate);
    // Fallback polling (in case socket is unavailable)
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    apiClient.stopFollowingDelivery(widget.deliveryId);
    _controller?.dispose();
    _poll?.cancel();
    super.dispose();
  }

  void _handleDeliveryUpdate(dynamic data) {
    if (data is! Map) return;
    final map = data.map((k, v) => MapEntry(k.toString(), v));
    if (!mounted) return;
    setState(() {
      _delivery = map;
      _loading = false;
    });
    _moveCameraIfPossible();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final d = await apiClient.fetchDeliveryById(widget.deliveryId);
      if (!mounted) return;
      setState(() {
        _delivery = d;
        _loading = false;
      });
      _moveCameraIfPossible();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _moveCameraIfPossible() {
    final lat = (_delivery?['lastLat'] as num?)?.toDouble();
    final lng = (_delivery?['lastLng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(lat, lng), zoom: 14)),
    );
  }

  Future<void> _loadCarrierMarkerIcon() async {
    try {
      // Ensure the asset exists; BitmapDescriptor.asset may fail silently on some platforms.
      await rootBundle.load(_kCarrierMarkerAssetPath);
      final icon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(56, 56)),
        _kCarrierMarkerAssetPath,
      );
      if (!mounted) return;
      setState(() => _carrierIcon = icon);
    } catch (_) {
      // Keep default marker.
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackingEnabled = (_delivery?['trackingEnabled'] == true);
    final lat = (_delivery?['lastLat'] as num?)?.toDouble();
    final lng = (_delivery?['lastLng'] as num?)?.toDouble();
    final hasLocation = lat != null && lng != null;

    final markers = <Marker>{
      if (hasLocation)
        Marker(
          markerId: const MarkerId('carrier'),
          position: LatLng(lat, lng),
          icon: _carrierIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: const InfoWindow(title: 'Taşıyıcı konumu'),
        ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Canlı Takip')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !trackingEnabled
              ? const Center(child: Text('Canlı takip henüz aktif değil.'))
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: BiTasiColors.backgroundGrey,
                      child: Text(
                        hasLocation
                            ? 'Taşıyıcı konumu güncellendi.'
                            : 'Taşıyıcı konumu henüz paylaşılmadı.',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    Expanded(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: hasLocation ? LatLng(lat, lng) : const LatLng(41.0082, 28.9784),
                          zoom: hasLocation ? 14 : 10,
                        ),
                        markers: markers,
                        onMapCreated: (c) => _controller = c,
                        zoomControlsEnabled: false,
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
                    ),
                  ],
                ),
    );
  }
}
