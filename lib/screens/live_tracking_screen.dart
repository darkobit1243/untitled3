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

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _delivery;
  bool _loading = true;
  GoogleMapController? _mapController;
  Timer? _poll;
  BitmapDescriptor? _carrierIcon;

  // Animasyon için
  late AnimationController _animController;
  late Animation<double> _anim;
  LatLng? _currentMarkerPosition; // Ekranda görünen (animasyonlu) konum
  LatLng? _targetMarkerPosition;  // Backend'den gelen son hedef
  LatLng? _animationStartPos;
  int _lastAnimBucket = -1;

  static const String _kCarrierMarkerAssetPath = 'assets/markers/kamyon_marker.png';

  @override
  void initState() {
    super.initState();
    
    // Animasyon kontrolcüsü (2 saniyelik geçiş süresi, yeni veri geldikçe resetlenir)
    _animController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2));
    _anim = CurvedAnimation(parent: _animController, curve: Curves.linear);

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() {
          _currentMarkerPosition = _targetMarkerPosition;
          _animationStartPos = null;
        });
      }
    });

    _animController.addListener(() {
      if (_currentMarkerPosition != null && _targetMarkerPosition != null) {
        final start = _animationStartPos ?? _currentMarkerPosition!;
        final end = _targetMarkerPosition!;
        final t = _anim.value;

        // GoogleMap rebuild'i pahalı; her frame setState yapma.
        // 2sn animasyonda ~10 adım yeterli görsel akıcılık sağlar.
        final bucket = (t * 10).floor();
        if (bucket == _lastAnimBucket) return;
        _lastAnimBucket = bucket;
        
        // Ara değeri hesapla
        final lat = start.latitude + (end.latitude - start.latitude) * t;
        final lng = start.longitude + (end.longitude - start.longitude) * t;
        
        setState(() => _currentMarkerPosition = LatLng(lat, lng));
        
        // Hafifçe kamerayı da odakla (kullanıcı etkileşimdeyse iptal edilebilir ama basitlik için)
        // _moveCameraIfPossible(); -> Her frame'de kamera oynatmak kullanıcıyı yorar,
        // sadece hedef değişiminde oynatmak daha iyi.
      }
    });

    _loadCarrierMarkerIcon();
    _load();
    apiClient.followDeliveryUpdates(widget.deliveryId, _handleDeliveryUpdate);
    // Fallback polling
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    apiClient.stopFollowingDelivery(widget.deliveryId);
    _mapController?.dispose();
    _poll?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _handleDeliveryUpdate(dynamic data) {
    if (data is! Map) return;
    final map = data.map((k, v) => MapEntry(k.toString(), v));
    _updateLocation(map);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final d = await apiClient.fetchDeliveryById(widget.deliveryId);
      if (!mounted) return;
      _updateLocation(d);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _updateLocation(Map<String, dynamic> data) {
    final lat = (data['lastLat'] as num?)?.toDouble();
    final lng = (data['lastLng'] as num?)?.toDouble();

    if (lat == null || lng == null) {
      if (mounted) {
        setState(() {
          _delivery = data;
          _loading = false;
        });
      }
      return;
    }

    final newTarget = LatLng(lat, lng);

    // Tek yerden state güncelle: double setState'ten kaçın.
    _animateTo(data, newTarget);
  }

  void _animateTo(Map<String, dynamic> newData, LatLng newTarget) {
     setState(() {
       _delivery = newData;
       _loading = false;
       
       if (_currentMarkerPosition == null) {
         _currentMarkerPosition = newTarget;
         _targetMarkerPosition = newTarget;
         _lastAnimBucket = -1;
         _moveCameraIfPossible(newTarget);
       } else {
         // Animasyon başlat
         _animationStartPos = _currentMarkerPosition;
         _targetMarkerPosition = newTarget;
         _lastAnimBucket = -1;
         _animController.reset();
         _animController.forward();
       }
     });
  }

  void _moveCameraIfPossible(LatLng target) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 14)),
    );
  }

  Future<void> _loadCarrierMarkerIcon() async {
    try {
      await rootBundle.load(_kCarrierMarkerAssetPath);
      final icon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(56, 56)),
        _kCarrierMarkerAssetPath,
      );
      if (!mounted) return;
      setState(() => _carrierIcon = icon);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final trackingEnabled = (_delivery?['trackingEnabled'] == true);
    // Konum var mı?
    final hasLocation = _currentMarkerPosition != null;

    final markers = <Marker>{
      if (hasLocation)
        Marker(
          markerId: const MarkerId('carrier'),
          // Burada _currentMarkerPosition'ı (animasyonluyu) kullanıyoruz
          position: _currentMarkerPosition!,
          icon: _carrierIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: const InfoWindow(title: 'Taşıyıcı'),
          rotation: 0, // İstenirse yön (heading) de eklenebilir
          anchor: const Offset(0.5, 0.5), // Merkeze oturt
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
                            ? 'Konum güncelleniyor...'
                            : 'Konum bekleniyor...',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    Expanded(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _currentMarkerPosition ?? const LatLng(41.0082, 28.9784),
                          zoom: 14,
                        ),
                        markers: markers,
                        onMapCreated: (c) => _mapController = c,
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
