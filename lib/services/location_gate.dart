import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Shared helper for location service + permission gating.
///
/// Goal: keep UX consistent across screens, avoid code duplication.
class LocationGate {
  static const String _serviceOffMessage =
      'Konum servisleri kapalı. Devam etmek için konumu aç.';
  static const String _permissionNeededMessage =
      'Konum izni gerekli. Lütfen izin ver.';
  static const String _permissionForeverMessage =
      'Konum izni kalıcı olarak reddedildi. Ayarlardan izin ver.';

  static void _showServiceDisabledSnack(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text(_serviceOffMessage),
        action: SnackBarAction(
          label: 'Ayarlar',
          onPressed: () {
            // ignore: unawaited_futures
            Geolocator.openLocationSettings();
          },
        ),
      ),
    );
  }

  static void _showPermissionSnack(
    BuildContext context, {
    required bool permanentlyDenied,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (permanentlyDenied) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(_permissionForeverMessage),
          action: SnackBarAction(
            label: 'Ayarlar',
            onPressed: () {
              // ignore: unawaited_futures
              Geolocator.openAppSettings();
            },
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text(_permissionNeededMessage)),
    );
  }

  /// Ensures location services are enabled + app has permission.
  ///
  /// - When [userInitiated] is true and [context] is provided, shows a SnackBar
  ///   with a Settings shortcut when blocked.
  /// - Returns `true` when location can be accessed.
  static Future<bool> ensureReady({
    BuildContext? context,
    bool userInitiated = false,
  }) async {
    try {
      final ctx = context;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (userInitiated && ctx != null) {
          if (!ctx.mounted) return false;
          _showServiceDisabledSnack(ctx);
        }
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (userInitiated && ctx != null) {
          if (!ctx.mounted) return false;
          _showPermissionSnack(ctx, permanentlyDenied: true);
        }
        return false;
      }

      if (permission == LocationPermission.denied) {
        if (userInitiated && ctx != null) {
          if (!ctx.mounted) return false;
          _showPermissionSnack(ctx, permanentlyDenied: false);
        }
        return false;
      }

      return true;
    } catch (_) {
      // Keep behavior consistent with existing code (silent failures unless
      // explicitly handled by screen).
      return false;
    }
  }
}
