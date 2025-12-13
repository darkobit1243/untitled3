import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'home_screen.dart'; // Birazdan oluşturacağız
import 'my_shipments_screen.dart'; // Birazdan oluşturacağız
import 'profile_screen.dart'; // Birazdan oluşturacağız
import 'carrier_deliveries_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;
  String? _role;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await apiClient.getPreferredRole();
    if (!mounted) return;
    setState(() {
      _role = role;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isCarrier = _role == 'carrier';
    final pages = <Widget>[
      HomeScreen(role: isCarrier ? 'carrier' : 'sender'),
      isCarrier ? const CarrierDeliveriesScreen() : const MyShipmentsScreen(),
      const Center(child: Text("Mesajlar (Yakında)")),
      const ProfileScreen(),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map),
        label: 'Keşfet',
      ),
      NavigationDestination(
        icon: Icon(isCarrier ? Icons.route_outlined : Icons.local_shipping_outlined),
        selectedIcon: Icon(isCarrier ? Icons.route : Icons.local_shipping),
        label: isCarrier ? 'Teslimatlar' : 'Kargolarım',
      ),
      const NavigationDestination(
        icon: Icon(Icons.chat_bubble_outline),
        selectedIcon: Icon(Icons.chat_bubble),
        label: 'Mesajlar',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profil',
      ),
    ];

    return Scaffold(
      // Seçili sayfayı göster
      body: pages[_currentIndex],

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: destinations,
      ),
    );
  }
}