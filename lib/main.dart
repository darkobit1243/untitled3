import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:ui';

import 'screens/login_screen.dart';
import 'screens/main_wrapper.dart';
import 'services/api_client.dart';
import 'services/app_navigator.dart';
import 'services/push_notifications.dart';
import 'services/push_config.dart';
import 'theme/trustship_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrintStack(stackTrace: details.stack);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };

  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase config may be missing in local/dev; app should still run.
  }
  runApp(const BiTasiApp());
}

class BiTasiApp extends StatelessWidget {
  const BiTasiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BiTaşı',
      debugShowCheckedModeBanner: false,
      theme: buildTrustShipTheme(),
      navigatorKey: appNavigatorKey,
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
    if (ok && kEnableFirebasePush) {
      await pushNotifications.syncWithSettings();
    }
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