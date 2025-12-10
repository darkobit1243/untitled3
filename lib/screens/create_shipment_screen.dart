// lib/screens/create_shipment_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
class CreateShipmentScreen extends StatefulWidget {
  const CreateShipmentScreen({super.key});

  @override
  State<CreateShipmentScreen> createState() => _CreateShipmentScreenState();
}

class _CreateShipmentScreenState extends State<CreateShipmentScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form verilerini tutacak değişkenler
  String? _title;
  String? _origin;
  String? _destination;
  double? _price;
  double? _weight;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kargo İlanı Oluştur')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Yeni gönderini birkaç adımda oluştur.',
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
                                'Kargo fotoğrafı yükle',
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
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(_pickedImage!.path),
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Gönderi Bilgileri',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                // 2. Başlık
                TextFormField(
                  decoration: _inputDecoration('Ne gönderiyorsun? (Örn: Kitap kolisi)'),
                  validator: (value) => value == null || value.isEmpty ? 'Lütfen bir başlık gir.' : null,
                  onSaved: (value) => _title = value,
                ),
                const SizedBox(height: 16),

                // 3. Nereden - Nereye (İleride Google Maps Autocomplete olacak)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: _inputDecoration('Nereden?', icon: Icons.my_location),
                        onSaved: (value) => _origin = value,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        decoration: _inputDecoration('Nereye?', icon: Icons.location_on),
                        onSaved: (value) => _destination = value,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text(
                  'Ağırlık & Teklif',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: _inputDecoration('Ağırlık (kg)', icon: Icons.scale),
                        keyboardType: TextInputType.number,
                        onSaved: (value) => _weight = double.tryParse(value ?? ''),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        decoration: _inputDecoration('Teklif (TL)', icon: Icons.currency_lira),
                        keyboardType: TextInputType.number,
                        onSaved: (value) => _price = double.tryParse(value ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 5. Gönder Butonu
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
                            'İlanı Yayınla',
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
  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      _createListing();
    }
  }

  Future<void> _createListing() async {
    if (_title == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await apiClient.createListing(
        title: _title!,
        description: '$_origin -> $_destination, teklif: $_price TL',
        weight: _weight ?? 0,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İlan oluşturuldu.')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İlan oluşturulamadı, tekrar dene.')),
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
}