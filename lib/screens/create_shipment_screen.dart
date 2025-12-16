// Kargo ilanı oluşturma + Google Maps / Places / Directions entegrasyonu

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../services/google_api_keys.dart';
import '../services/location_gate.dart';
import 'home_common.dart';
import 'location_picker_screen.dart';

class CreateShipmentScreen extends StatefulWidget {
  const CreateShipmentScreen({super.key});

  @override
  State<CreateShipmentScreen> createState() => _CreateShipmentScreenState();
}

class _CreateShipmentScreenState extends State<CreateShipmentScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form alanları
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _weightController = TextEditingController();
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();

  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;

  // Google Maps & Places state
  final Dio _dio = Dio();
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  BitmapDescriptor? _cargoPinIcon;

  // (Autocomplete bu ekranda değil, tam ekran LocationPicker'da yapılıyor)

  static const CameraPosition _fallbackCamera = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 10,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCurrentLocation();
      _prepareMarkerIcons();
    });
  }

  Future<void> _prepareMarkerIcons() async {
    try {
      final icon = await createCargoPinMarkerBitmapDescriptor(size: 86);
      if (!mounted) return;
      setState(() {
        _cargoPinIcon = icon;
      });
      _updateMarkersAndRoute();
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _weightController.dispose();
    _pickupController.dispose();
    _dropoffController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kargo Gönderim Ekranı')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Kargo detaylarını gir, kargonu birkaç adımda oluştur.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // 1. Kargo Fotoğraf Alanı
                GestureDetector(
                  onTap: _pickImageFromGallery,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _pickedImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                'Kargo fotoğrafı yükle *',
                                style: TextStyle(color: Colors.grey),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Galeri açılacak, bir görsel seç.',
                                style: TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_pickedImage!.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Gönderi Bilgileri
                const Text(
                  'Gönderi Bilgileri',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: _inputDecoration(
                    'Başlık *',
                    hint: 'Örn: Laptop Taşıma - İstanbul → Ankara',
                    icon: Icons.local_shipping_outlined,
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Lütfen bir başlık gir.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: _inputDecoration(
                    'Açıklama *',
                    hint: 'Gönderiniz hakkında detaylı bilgi verin...',
                  ),
                  maxLines: 4,
                  validator: (value) => value == null || value.isEmpty ? 'Lütfen açıklama gir.' : null,
                ),
                const SizedBox(height: 24),

                // Ağırlık
                const Text(
                  'Ağırlık',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _weightController,
                  decoration: _inputDecoration(
                    'Ağırlık (kg) *',
                    hint: '2.5',
                    icon: Icons.scale,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Geçerli bir ağırlık gir.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Konum Bilgileri (tıklayınca tam ekran harita açılır)
                const Text(
                  'Konum Bilgileri',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pickupController,
                  decoration: _inputDecoration(
                    'Alış Noktası *',
                    hint: 'İstanbul Kadıköy...',
                    icon: Icons.my_location,
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Lütfen alış noktasını gir.' : null,
                  readOnly: true,
                  onTap: () async {
                    final result = await Navigator.push<LocationResult?>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationPickerScreen(
                          title: 'Alış Noktası Seç',
                          initialPosition: _pickupLocation ?? _currentLocation,
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _pickupLocation = result.position;
                        _pickupController.text = result.description;
                      });
                      _updateMarkersAndRoute();
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dropoffController,
                  decoration: _inputDecoration(
                    'Teslim Noktası *',
                    hint: 'Ankara Çankaya...',
                    icon: Icons.location_on,
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Lütfen teslim noktasını gir.' : null,
                  readOnly: true,
                  onTap: () async {
                    final result = await Navigator.push<LocationResult?>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationPickerScreen(
                          title: 'Teslim Noktası Seç',
                          initialPosition: _dropoffLocation ?? _currentLocation,
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _dropoffLocation = result.position;
                        _dropoffController.text = result.description;
                      });
                      _updateMarkersAndRoute();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Harita + rota
                SizedBox(
                  height: 230,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: _currentLocation != null
                              ? CameraPosition(target: _currentLocation!, zoom: 12)
                              : _fallbackCamera,
                          myLocationEnabled: _currentLocation != null,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          markers: _markers,
                          polylines: _polylines,
                          onMapCreated: (controller) {
                            _mapController = controller;
                          },
                        ),
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: IconButton(
                              icon: const Icon(Icons.my_location, color: Colors.blueAccent),
                              onPressed: _goToCurrentLocation,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Gönder Butonu
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Kargo Oluştur',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tasarım tekrarını önlemek için yardımcı metod
  InputDecoration _inputDecoration(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_pickedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf eklemeden devam edemezsiniz.')),
        );
        return;
      }
      if (_pickupLocation == null || _dropoffLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen haritadan alış ve teslim noktalarını seç.')),
        );
        return;
      }
      _createListing();
    }
  }
              
  String _inferMimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<String> _buildPickedImageDataUrl() async {
    final picked = _pickedImage;
    if (picked == null) {
      throw StateError('picked image is null');
    }
    final bytes = await File(picked.path).readAsBytes();
    final b64 = base64Encode(bytes);
    final mime = _inferMimeTypeFromPath(picked.path);
    return 'data:$mime;base64,$b64';
  }

  Future<void> _createListing() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final weight = double.tryParse(_weightController.text.trim()) ?? 0;

      final photoDataUrl = await _buildPickedImageDataUrl();

      await apiClient.createListing(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        photoDataUrl: photoDataUrl,
        weight: weight,
        // Boyut ve kırılabilirlik alanlarını şimdilik varsayılan gönderiyoruz.
        length: 0,
        width: 0,
        height: 0,
        fragile: false,
        // Koordinatlar Google Places'tan gelen değerlere göre.
        pickupLat: _pickupLocation!.latitude,
        pickupLng: _pickupLocation!.longitude,
        dropoffLat: _dropoffLocation!.latitude,
        dropoffLng: _dropoffLocation!.longitude,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kargo oluşturuldu.')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kargo oluşturulamadı, tekrar dene.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (image == null) return;
      setState(() {
        _pickedImage = image;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Galeri açılamadı, izinleri kontrol et.')),
      );
    }
  }

  // --- Konum & Google Places / Directions helper'ları ---

  Future<void> _initCurrentLocation({bool userInitiated = false}) async {
    try {
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

      _updateMarkersAndRoute();

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 12),
        ),
      );
    } catch (_) {
      // Konum alınamazsa sessiz geç.
    }
  }

  Future<void> _setLastKnownLocation() async {
    if (_currentLocation != null) return;
    final last = await Geolocator.getLastKnownPosition();
    if (last == null) return;
    _currentLocation = LatLng(last.latitude, last.longitude);
    _updateMarkersAndRoute();
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLocation!, zoom: 12),
      ),
    );
  }

  Future<void> _goToCurrentLocation() async {
    if (_currentLocation == null) {
      await _ensureCurrentLocation(userInitiated: true);
    }
    if (_mapController != null && _currentLocation != null) {
      await _mapController!.animateCamera(
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
      _currentLocation = LatLng(last.latitude, last.longitude);
      _updateMarkersAndRoute();
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 12),
        ),
      );
      return;
    }
    await _initCurrentLocation(userInitiated: userInitiated);
  }

  void _updateMarkersAndRoute() {
    setState(() {
      _markers.clear();

      if (_currentLocation != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('current'),
            position: _currentLocation!,
            infoWindow: const InfoWindow(title: 'Mevcut Konumun'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );
      }

      if (_pickupLocation != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: _pickupLocation!,
            infoWindow: const InfoWindow(title: 'Alış Noktası'),
            icon: _cargoPinIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          ),
        );
      }

      if (_dropoffLocation != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('dropoff'),
            position: _dropoffLocation!,
            infoWindow: const InfoWindow(title: 'Teslim Noktası'),
            icon: _cargoPinIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        );
      }

      _polylines.clear();
    });

    if (_pickupLocation != null && _dropoffLocation != null) {
      _drawRoute(_pickupLocation!, _dropoffLocation!);
    }
  }

  Future<void> _drawRoute(LatLng origin, LatLng destination) async {
    try {
      assert(
        GoogleApiKeys.mapsWebApiKey.isNotEmpty,
        'Missing GOOGLE_MAPS_WEB_API_KEY (pass via --dart-define).',
      );
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: <String, dynamic>{
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
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

      // İki noktayı aynı anda görebilmek için kamera sınırlarını ayarla
      if (_mapController != null) {
        final southWest = LatLng(
          math.min(origin.latitude, destination.latitude),
          math.min(origin.longitude, destination.longitude),
        );
        final northEast = LatLng(
          math.max(origin.latitude, destination.latitude),
          math.max(origin.longitude, destination.longitude),
        );

        final bounds = LatLngBounds(southwest: southWest, northeast: northEast);

        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 60), // 60px padding
        );
      }
    } catch (_) {
      // Hata durumunda sessiz geç.
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
}