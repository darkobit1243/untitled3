// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'create_shipment_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Başlangıç Konumu (Örn: İstanbul)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 12,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Harita tam ekran olacak, Stack ile butonları üzerine koyacağız
      body: Stack(
        children: [
          // Katman 1: Harita
          GoogleMap(
            initialCameraPosition: _initialPosition,
            // Konum izinleri ve runtime permission akışı eklenene kadar
            // çökme riskini azaltmak için myLocationEnabled'i geçici olarak kapattık.
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              // Harita yüklendiğinde yapılacaklar
            },
          ),

          // Katman 2: Alt Kısımdaki Action Butonları
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Kargo Gönder Butonu
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.add_box,
                        label: "Kargo\nGönder",
                        color: const Color(0xFF0D47A1), // Mavi
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CreateShipmentScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 15),
                    // Rota Bul Butonu
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.directions_car,
                        label: "Rota\nBul",
                        color: const Color(0xFF2E7D32), // Yeşil
                        onTap: () {
                          // Rota arama ekranına gidecek
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Katman 3: Üst Arama Çubuğu (Estetik)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Row(
                children: const [
                  Icon(Icons.search, color: Colors.grey),
                  SizedBox(width: 10),
                  Text("Kargo veya Rota Ara...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 5),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}