import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotifications {
  LocalNotifications();

  static const String kDefaultChannelId = 'bitasi_default';
  static const String kDefaultChannelName = 'BiTaşı';
  static const String kDefaultChannelDescription = 'BiTaşı bildirimleri';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  
  /// Tıklama olayını dinlemek isteyenler (örn: main.dart veya PushNotifications) buraya fonksiyon atayabilir.
  Function(Map<String, dynamic>)? onNotificationTap;

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null && onNotificationTap != null) {
          try {
            final dynamic data = _decodePayload(details.payload!);
            if (data is Map<String, dynamic>) {
               onNotificationTap!(data);
            }
          } catch (_) {}
        }
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          kDefaultChannelId,
          kDefaultChannelName,
          description: kDefaultChannelDescription,
          importance: Importance.high,
        ),
      );

      // Android 13+ runtime permission.
      await android?.requestNotificationsPermission();
    }

    if (!kIsWeb && Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  Future<void> showWelcome({required String fullName}) async {
    await init();

    final safeName = fullName.trim().isEmpty ? 'BiTaşı' : fullName.trim();
    await _plugin.show(
      1001,
      'Hoş geldiniz',
      safeName,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kDefaultChannelId,
          kDefaultChannelName,
          channelDescription: kDefaultChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showFromRemoteMessage(RemoteMessage message) async {
    await init();

    final title = message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();

    if ((title ?? '').trim().isEmpty && (body ?? '').trim().isEmpty) return;

    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
    
    String? payload;
    try {
      if (message.data.isNotEmpty) {
        payload = jsonEncode(message.data);
      }
    } catch (_) {
      // JSON encode hatası olursa payload null kalsın.
    }

    await _plugin.show(
      id,
      (title ?? 'BiTaşı').trim(),
      (body ?? '').trim(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kDefaultChannelId,
          kDefaultChannelName,
          channelDescription: kDefaultChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  dynamic _decodePayload(String payload) {
     return jsonDecode(payload);
  }
}

final localNotifications = LocalNotifications();
