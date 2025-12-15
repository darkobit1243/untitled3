import 'dart:async';

import 'package:flutter/material.dart' as m;
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_client.dart';
import 'app_settings.dart';
import 'app_navigator.dart';
import 'push_config.dart';
import '../screens/main_wrapper.dart';

class PushNotifications {
  PushNotifications();

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  bool _handlersBound = false;

  Future<void> init() async {
    if (!kEnableFirebasePush) return;
    final enabled = await appSettings.getNotificationsEnabled();
    if (!enabled) {
      await _unregisterToken();
      return;
    }

    // iOS permission prompt; on Android it is a no-op.
    await FirebaseMessaging.instance.requestPermission();

    await _registerCurrentToken();

    _tokenSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _registerToken(token);
    });

    if (!_handlersBound) {
      _handlersBound = true;

      // Foreground: show a lightweight in-app SnackBar (system notification won't show by default)
      _onMessageSub ??= FirebaseMessaging.onMessage.listen((message) async {
        final enabledNow = await appSettings.getNotificationsEnabled();
        if (!enabledNow) return;

        final ctx = appNavigatorKey.currentContext;
        if (ctx == null) return;
        final title = message.notification?.title;
        final body = message.notification?.body;
        if ((title ?? '').isEmpty && (body ?? '').isEmpty) return;

        // ignore: use_build_context_synchronously
        m.ScaffoldMessenger.of(ctx).showSnackBar(
          m.SnackBar(content: m.Text(body ?? title ?? 'Bildirim')),
        );
      });

      // Background tap: navigate
      _onOpenedSub ??= FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleOpen(message);
      });

      // Terminated -> opened
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _handleOpen(initial);
      }
    }
  }

  void _handleOpen(RemoteMessage message) {
    final data = message.data;
    final type = data['type']?.toString();
    final listingId = data['listingId']?.toString();

    if (type == 'offer' && listingId != null && listingId.isNotEmpty) {
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

    // Default: just open the app main shell.
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      m.MaterialPageRoute<void>(builder: (_) => const MainWrapper()),
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
