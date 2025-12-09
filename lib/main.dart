import 'package:flutter/material.dart';
import 'theme/trustship_theme.dart';
import 'screens/main_dashboard_screen.dart';

void main() {
  runApp(const TrustShipApp());
}

class TrustShipApp extends StatelessWidget {
  const TrustShipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrustShip',
      debugShowCheckedModeBanner: false,
      theme: buildTrustShipTheme(),
      home: const MainDashboardScreen(),
    );
  }
}