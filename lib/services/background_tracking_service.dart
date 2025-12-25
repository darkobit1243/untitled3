import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Background (and foreground) live-tracking sender for carriers.
///
/// Notes:
/// - Android: uses a foreground service so it can keep running.
/// - iOS: location background execution is OS-controlled; 15s interval is best-effort.
class BackgroundTrackingService {
  static const String _baseUrl = 'https://kargo-backend-production.up.railway.app';
  static const String _prefsDeliveryIdsKey = 'bg_tracking_delivery_ids_v1';
  static const String _prefsAuthTokenKey = 'auth_token';
  static const String _prefsRefreshTokenKey = 'refresh_token';

  static const int _notificationId = 9821;
  static const int _tickSeconds = 15;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: bgTrackingOnStart,
        autoStart: false,
        isForegroundMode: true,
        foregroundServiceNotificationId: _notificationId,
        initialNotificationTitle: 'BiTaşı',
        initialNotificationContent: 'Canlı takip açık',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: bgTrackingOnStart,
        onBackground: bgTrackingOnIosBackground,
      ),
    );
  }

  /// Starts (if needed) and updates the set of deliveries that should be tracked.
  ///
  /// Pass empty set to stop.
  static Future<void> syncDeliveries(Set<String> deliveryIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsDeliveryIdsKey, deliveryIds.toList());

    final service = FlutterBackgroundService();
    if (deliveryIds.isEmpty) {
      await stop();
      return;
    }

    final running = await service.isRunning();
    if (!running) {
      await service.startService();
    }

    service.invoke('setDeliveries', <String, dynamic>{
      'ids': deliveryIds.toList(),
    });
  }

  static Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsDeliveryIdsKey);

    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  static Future<void> _postDeliveryLocation(
    String deliveryId, {
    required double lat,
    required double lng,
    required String token,
  }) async {
    final uri = Uri.parse('$_baseUrl/deliveries/$deliveryId/location');
    final resp = await http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, dynamic>{'lat': lat, 'lng': lng}),
    );

    if (resp.statusCode != 401) return;

    // Token invalid/expired: best-effort refresh and retry once.
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_prefsRefreshTokenKey);
    if (refreshToken == null || refreshToken.trim().isEmpty) return;

    final refreshResp = await http.post(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{'refreshToken': refreshToken.trim()}),
    );
    if (refreshResp.statusCode >= 400) return;

    final data = jsonDecode(refreshResp.body);
    if (data is! Map) return;
    final newToken = (data['token'] as String?)?.trim();
    final newRefresh = (data['refreshToken'] as String?)?.trim();
    if (newToken == null || newToken.isEmpty) return;

    await prefs.setString(_prefsAuthTokenKey, newToken);
    if (newRefresh != null && newRefresh.isNotEmpty) {
      await prefs.setString(_prefsRefreshTokenKey, newRefresh);
    }

    await http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $newToken',
      },
      body: jsonEncode(<String, dynamic>{'lat': lat, 'lng': lng}),
    );
  }
}

/// Top-level entrypoints for `flutter_background_service`.
///
/// Keeping these as top-level functions avoids callback-handle / tree-shaking
/// edge-cases that can surface as `MissingPluginException` on some Android builds.
@pragma('vm:entry-point')
Future<bool> bgTrackingOnIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void bgTrackingOnStart(ServiceInstance service) {
  // Must run before using any plugin (SharedPreferences, Geolocator, etc.).
  DartPluginRegistrant.ensureInitialized();
  // ignore: unawaited_futures
  _bgTrackingOnStartAsync(service);
}

Future<void> _bgTrackingOnStartAsync(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
  }

  Timer? timer;
  List<String> deliveryIds = <String>[];
  var tickCount = 0;

  Future<void> refreshDeliveryIds() async {
    final prefs = await SharedPreferences.getInstance();
    deliveryIds = prefs.getStringList(BackgroundTrackingService._prefsDeliveryIdsKey) ?? <String>[];
  }

  Future<void> postLocationTick() async {
    tickCount += 1;
    await refreshDeliveryIds();
    if (deliveryIds.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(BackgroundTrackingService._prefsAuthTokenKey);
    if (token == null || token.isEmpty) return;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );

      final lat = pos.latitude;
      final lng = pos.longitude;

      for (final id in deliveryIds) {
        if (id.trim().isEmpty) continue;
        // Best-effort; ignore individual failures.
        // ignore: unawaited_futures
        BackgroundTrackingService._postDeliveryLocation(id.trim(), lat: lat, lng: lng, token: token);
      }

      if (service is AndroidServiceInstance) {
        final now = DateTime.now();
        final hh = now.hour.toString().padLeft(2, '0');
        final mm = now.minute.toString().padLeft(2, '0');
        final ss = now.second.toString().padLeft(2, '0');
        final debugSuffix = kDebugMode ? ' • #$tickCount • $hh:$mm:$ss' : '';
        service.setForegroundNotificationInfo(
          title: 'BiTaşı',
          content: 'Canlı takip açık (${deliveryIds.length})$debugSuffix',
        );

        if (kDebugMode) {
          debugPrint('[BG] tick #$tickCount: sent location for ${deliveryIds.length} delivery(ies)');
        }
      }
    } catch (_) {
      // Silent fail.
    }
  }

  service.on('setDeliveries').listen((event) async {
    final ids = (event?['ids'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(BackgroundTrackingService._prefsDeliveryIdsKey, ids);
    deliveryIds = ids;
    await postLocationTick();
  });

  service.on('stopService').listen((_) async {
    timer?.cancel();
    timer = null;
    try {
      await refreshDeliveryIds();
    } catch (_) {}
    try {
      service.stopSelf();
    } catch (_) {}
  });

  await refreshDeliveryIds();
  await postLocationTick();

  timer = Timer.periodic(const Duration(seconds: BackgroundTrackingService._tickSeconds), (_) {
    // ignore: unawaited_futures
    postLocationTick();
  });
}
