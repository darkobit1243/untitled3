import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/auth/login_screen.dart';
import 'screens/main_wrapper.dart';
import 'services/api_client.dart';
import 'services/app_navigator.dart';
import 'services/background_tracking_service.dart';
import 'services/local_notifications.dart';
import 'services/push_notifications.dart';
import 'services/push_config.dart';
import 'theme/bitasi_theme.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Ignore if Firebase config is missing.
  }

  try {
    await localNotifications.showFromRemoteMessage(message);
  } catch (_) {
    // Ignore notification errors in background isolate.
  }
}

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
  
  // FCM token'ı alıp konsola yazdır
  try {
    String? token = await FirebaseMessaging.instance.getToken();
    print('---------------------------------------');
    print('BULDUM LAN TOKENI: $token');
    print('---------------------------------------');
  } catch (e) {
    print('TOKEN ALIRKEN PATLADIK: $e');
  }

  if (kEnableFirebasePush) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Local notifications (welcome + data-only FCM display)
  try {
    await localNotifications.init();
  } catch (_) {
    // Ignore: local notifications may fail on unsupported platforms.
  }

  // Configure background tracking service (Android foreground service / iOS background hooks).
  await BackgroundTrackingService.initialize();
  runApp(const ProviderScope(child: BiTasiApp()));
}

class BiTasiApp extends StatelessWidget {
  const BiTasiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BiTaşı',
      debugShowCheckedModeBanner: false,
      theme: buildBiTasiTheme(),
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
      try {
        await pushNotifications.syncWithSettings();
      } catch (_) {
        // Push is best-effort; don't block app usage.
      }
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