import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/main_wrapper.dart';
import 'services/api_client.dart';
import 'theme/trustship_theme.dart';

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
      home: const _RootDecider(),
    );
  }
}

/// Uygulama açıldığında token var mı yok mu kontrol eden kök widget.
class _RootDecider extends StatefulWidget {
  const _RootDecider();

  @override
  State<_RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<_RootDecider> {
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final ok = await apiClient.tryRestoreSession();
    if (!mounted) return;
    setState(() {
      _loggedIn = ok;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loggedIn) {
      return const MainWrapper();
    }

    return const LoginScreen();
  }
}