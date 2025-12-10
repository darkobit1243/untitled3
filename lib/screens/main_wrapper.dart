import 'package:flutter/material.dart';
import 'home_screen.dart'; // Birazdan oluşturacağız
import 'my_shipments_screen.dart'; // Birazdan oluşturacağız
import 'profile_screen.dart'; // Birazdan oluşturacağız

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  // Sayfaların Listesi
  final List<Widget> _pages = [
    const HomeScreen(),        // Anasayfa (Harita ve İlanlar)
    const MyShipmentsScreen(), // Kargo Hareketleri
    const Center(child: Text("Mesajlar (Yakında)")),
    const ProfileScreen(),     // Profil & Cüzdan
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Seçili sayfayı göster
      body: _pages[_currentIndex],

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Keşfet',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Kargolarım',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Mesajlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}