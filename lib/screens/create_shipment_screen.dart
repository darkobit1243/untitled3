// Kargo ilanı oluşturma + Google Maps / Places / Directions entegrasyonu

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/create_shipment_provider.dart';
import '../services/location_gate.dart';
import 'location_picker_screen.dart';

class CreateShipmentScreen extends ConsumerStatefulWidget {
  const CreateShipmentScreen({super.key});

  @override
  ConsumerState<CreateShipmentScreen> createState() => _CreateShipmentScreenState();
}

class _CreateShipmentScreenState extends ConsumerState<CreateShipmentScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form alanları (Text controller UI'a özeldir, burada kalabilir)
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _weightController = TextEditingController();
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _receiverPhoneController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  GoogleMapController? _mapController;

  static const CameraPosition _fallbackCamera = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 10,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initHelper();
    });
  }

  Future<void> _initHelper() async {
    // Marker ikonlarını yükle ve provider'a set et
    try {
      const markerSize = 56.0;
      const config = ImageConfiguration(size: Size(markerSize, markerSize));

      final pickupIcon = await BitmapDescriptor.fromAssetImage(
        config,
        'assets/markers/Alis_noktasi.png',
      );
      final dropoffIcon = await BitmapDescriptor.fromAssetImage(
        config,
        'assets/markers/Varis_noktasi.png',
      );
      
      if (mounted) {
        ref.read(createShipmentProvider.notifier).setIcons(pickupIcon, dropoffIcon);
      }
    } catch (_) {}

    await _initCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _weightController.dispose();
    _pickupController.dispose();
    _dropoffController.dispose();
    _receiverPhoneController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // State'i dinle
    final state = ref.watch(createShipmentProvider);

    // Hata veya Başarı durumlarını dinlemek için listen
    ref.listen(createShipmentProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
      if (next.isSuccess && (previous == null || !previous.isSuccess)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kargo oluşturuldu.')),
        );
        Navigator.pop(context);
      }
    });

    // Form alanlarını güncelle (eğer haritadan seçildiyse)
    if (state.pickupAddress != null && _pickupController.text != state.pickupAddress) {
      _pickupController.text = state.pickupAddress!;
    }
    if (state.dropoffAddress != null && _dropoffController.text != state.dropoffAddress) {
      _dropoffController.text = state.dropoffAddress!;
    }

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
                    child: state.pickedImage == null
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
                              File(state.pickedImage!.path),
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
                  validator: (value) => state.pickupLocation == null ? 'Lütfen alış noktasını gir.' : null,
                  readOnly: true,
                  onTap: () async {
                    final result = await Navigator.push<LocationResult?>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationPickerScreen(
                          title: 'Alış Noktası Seç',
                          initialPosition: state.pickupLocation ?? state.currentLocation,
                          markerKind: LocationPickerMarkerKind.pickup,
                        ),
                      ),
                    );
                    if (result != null) {
                      ref.read(createShipmentProvider.notifier).setPickup(result.position, result.description);
                      _updateMapBounds(state.pickupLocation, state.dropoffLocation);
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
                  validator: (value) => state.dropoffLocation == null ? 'Lütfen teslim noktasını gir.' : null,
                  readOnly: true,
                  onTap: () async {
                    final result = await Navigator.push<LocationResult?>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationPickerScreen(
                          title: 'Teslim Noktası Seç',
                          initialPosition: state.dropoffLocation ?? state.currentLocation,
                          markerKind: LocationPickerMarkerKind.dropoff,
                        ),
                      ),
                    );
                    if (result != null) {
                      ref.read(createShipmentProvider.notifier).setDropoff(result.position, result.description);
                      _updateMapBounds(state.pickupLocation, state.dropoffLocation);
                    }
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _receiverPhoneController,
                  decoration: _inputDecoration(
                    'Alıcı Telefon Numarası *',
                    hint: '05xx xxx xx xx',
                    icon: Icons.phone,
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Alıcı telefon numarası gerekli.';
                    if (v.replaceAll(RegExp(r'\D'), '').length < 10) {
                      return 'Geçerli bir telefon numarası gir.';
                    }
                    return null;
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
                          initialCameraPosition: state.currentLocation != null
                              ? CameraPosition(target: state.currentLocation!, zoom: 12)
                              : _fallbackCamera,
                          myLocationEnabled: state.currentLocation != null,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          markers: state.markers,
                          polylines: state.polylines,
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
                    onPressed: state.isLoading ? null : _submitForm,
                    child: state.isLoading
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
      ref.read(createShipmentProvider.notifier).submitListing(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        weight: double.tryParse(_weightController.text.trim()) ?? 0,
        receiverPhone: _receiverPhoneController.text.trim(),
      );
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
      ref.read(createShipmentProvider.notifier).setImage(image);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Galeri açılamadı, izinleri kontrol et.')),
      );
    }
  }

  // --- Konum Helperları ---

  Future<void> _initCurrentLocation({bool userInitiated = false}) async {
    try {
      final ok = await LocationGate.ensureReady(
        context: context,
        userInitiated: userInitiated,
      );
      if (!ok) return;

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final loc = LatLng(last.latitude, last.longitude);
        ref.read(createShipmentProvider.notifier).setCurrentLocation(loc);
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: loc, zoom: 12),
          ),
        );
      }
      
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      final currentLoc = LatLng(pos.latitude, pos.longitude);
      ref.read(createShipmentProvider.notifier).setCurrentLocation(currentLoc);

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: currentLoc, zoom: 12),
        ),
      );
    } catch (_) {
      // Konum alınamazsa sessiz geç.
    }
  }

  Future<void> _goToCurrentLocation() async {
    await _initCurrentLocation(userInitiated: true);
    final current = ref.read(createShipmentProvider).currentLocation;
    if (_mapController != null && current != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: current, zoom: 14),
        ),
      );
    }
  }
  
  void _updateMapBounds(LatLng? p1, LatLng? p2) {
    if (p1 == null || p2 == null || _mapController == null) return;
    
    final southWest = LatLng(
      math.min(p1.latitude, p2.latitude),
      math.min(p1.longitude, p2.longitude),
    );
    final northEast = LatLng(
      math.max(p1.latitude, p2.latitude),
      math.max(p1.longitude, p2.longitude),
    );

    final bounds = LatLngBounds(southwest: southWest, northeast: northEast);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }
}