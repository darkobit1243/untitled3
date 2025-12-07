// lib/screens/create_shipment_screen.dart

import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kargo İlanı Oluştur")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Kargo Fotoğraf Alanı (Placeholder)
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                    Text("Kargo Fotoğrafı Yükle"),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Başlık
              TextFormField(
                decoration: _inputDecoration("Ne Gönderiyorsunuz? (Örn: Kitap Kolisi)"),
                validator: (value) => value!.isEmpty ? "Lütfen bir başlık girin" : null,
                onSaved: (value) => _title = value,
              ),
              const SizedBox(height: 15),

              // 3. Nereden - Nereye (İleride Google Maps Autocomplete olacak)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: _inputDecoration("Nereden?", icon: Icons.my_location),
                      onSaved: (value) => _origin = value,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      decoration: _inputDecoration("Nereye?", icon: Icons.location_on),
                      onSaved: (value) => _destination = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // 4. Ağırlık ve Fiyat
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: _inputDecoration("Ağırlık (kg)", icon: Icons.scale),
                      keyboardType: TextInputType.number,
                      onSaved: (value) => _weight = double.tryParse(value!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      decoration: _inputDecoration("Teklif (TL)", icon: Icons.currency_lira),
                      keyboardType: TextInputType.number,
                      onSaved: (value) => _price = double.tryParse(value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // 5. Gönder Butonu
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  "İlanı Yayınla",
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // Veritabanı (Firebase) kodu buraya gelecek
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("İlan Oluşturuluyor: $_title -> $_price TL")),
      );
    }
  }
}