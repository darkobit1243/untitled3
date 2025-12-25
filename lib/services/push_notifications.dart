import 'dart:async';

import 'package:flutter/material.dart' as m;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

import 'api_client.dart';
import 'app_settings.dart';
import 'app_navigator.dart';
import 'push_config.dart';
import 'local_notifications.dart';
import '../screens/main_wrapper.dart';

class PushNotifications {
  PushNotifications();

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  bool _handlersBound = false;

  Map<String, dynamic>? _pendingOpenData;
  bool _pendingNavScheduled = false;

  Future<void> init() async {
    if (!kEnableFirebasePush) return;

    // If Firebase isn't configured (dev), don't crash the app.
    if (Firebase.apps.isEmpty) return;
    
    // Bind local notification tap
    localNotifications.onNotificationTap = (data) {
      _handleOpenData(data);
    };

    final enabled = await appSettings.getNotificationsEnabled();
    if (!enabled) {
      await _unregisterToken();
      return;
    }

    // iOS permission prompt; on Android 13+ permission is handled via local notifications init.
    await FirebaseMessaging.instance.requestPermission();

    try {
      await _registerCurrentToken();
    } catch (_) {
      // Some devices/builds can fail to obtain an FCM token (e.g. FIS_AUTH_ERROR).
      // Push is best-effort and must not block app usage.
    }

    _tokenSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      // ignore: unawaited_futures
      _registerToken(token);
    });

    if (!_handlersBound) {
      _handlersBound = true;

      // Foreground: show a lightweight in-app SnackBar (system notification won't show by default)
      _onMessageSub ??= FirebaseMessaging.onMessage.listen((message) async {
        final enabledNow = await appSettings.getNotificationsEnabled();
        if (!enabledNow) return;
        
        // Show local notification for heads-up appearance if desired,
        // or just Snackbar as before. Syncing with user preference is good.
        // For now, keeping the snackbar logic but also triggering local notification 
        // allows 'tap' to work even for foreground messages if the user pulls down the shade.
        await localNotifications.showFromRemoteMessage(message);
      });

      // Background tap: navigate
      _onOpenedSub ??= FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleOpenData(message.data);
      });

      // Terminated -> opened
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _handleOpenData(initial.data);
      }
    }
  }

  void _handleOpenData(Map<String, dynamic> data) {
    // When the app is launched from a terminated state (especially via a local
    // notification tap), navigator may not be ready yet. Defer routing until
    // after the first frame.
    if (appNavigatorKey.currentState == null) {
      _pendingOpenData = Map<String, dynamic>.from(data);
      if (!_pendingNavScheduled) {
        _pendingNavScheduled = true;
        m.WidgetsBinding.instance.addPostFrameCallback((_) {
          _pendingNavScheduled = false;
          final pending = _pendingOpenData;
          _pendingOpenData = null;
          if (pending != null) {
            _handleOpenData(pending);
          }
        });
      }
      return;
    }

    final type = data['type']?.toString();
    final normalizedType = type?.trim().toLowerCase();
    final listingId = data['listingId']?.toString();
    final deliveryId = data['deliveryId']?.toString();
    final messageId = data['messageId']?.toString();

    if (normalizedType == 'offer' && listingId != null && listingId.isNotEmpty) {
      // Teklif geldiğinde "Kargolarım" sekmesine (index 1) ve detayına git
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        m.MaterialPageRoute<void>(
          builder: (_) => MainWrapper(
            initialIndex: 1,
            initialOpenOffersListingId: listingId,
          ),
        ),
        (route) => false,
      );
      return;
    }
    
    if (normalizedType == 'offer_accepted') {
      // Teklif kabul edildi -> Taşıyıcı/Teslimatlar (index 1)
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        m.MaterialPageRoute<void>(
          builder: (_) => const MainWrapper(initialIndex: 1),
        ),
        (route) => false,
      );
      return;
    }

    final isDeliveryEvent =
        normalizedType == 'delivery_status' ||
        normalizedType == 'delivery' ||
        (normalizedType != null && normalizedType.startsWith('delivery_')) ||
        (deliveryId != null && deliveryId.isNotEmpty);

    if (isDeliveryEvent) {
      // Teslimat güncellemesi (Taşımalarım veya Kargolarım) -> Index 1
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        m.MaterialPageRoute<void>(
          builder: (_) => const MainWrapper(initialIndex: 1),
        ),
        (route) => false,
      );
      return;
    }

    final looksLikeMessage =
        normalizedType == 'message' ||
        (messageId != null && messageId.isNotEmpty && listingId != null && listingId.isNotEmpty);

    if (looksLikeMessage) {
      // Sohbet -> Index 2 (Mesajlar)
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        m.MaterialPageRoute<void>(
          builder: (_) => const MainWrapper(initialIndex: 2),
        ),
        (route) => false,
      );
      return;
    }

    // Default: just open the app main shell (Home tab)
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      m.MaterialPageRoute<void>(builder: (_) => const MainWrapper(initialIndex: 0)),
      (route) => false,
    );
  }

  Future<void> syncWithSettings() async {
    if (!kEnableFirebasePush) return;
    final enabled = await appSettings.getNotificationsEnabled();
    if (enabled) {
      await init();
    } else {
      await _unregisterToken();
    }
  }

  Future<void> _registerCurrentToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.trim().isEmpty) return;
    await _registerToken(token.trim());
  }

  Future<void> _registerToken(String token) async {
    try {
      await apiClient.registerFcmToken(token);
    } catch (_) {
      // Ignore: backend might not be configured yet.
    }
  }

  Future<void> _unregisterToken() async {
    try {
      await apiClient.registerFcmToken(null);
    } catch (_) {
      // Ignore.
    }
  }
}

final pushNotifications = PushNotifications();
