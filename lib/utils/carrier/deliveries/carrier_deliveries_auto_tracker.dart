import 'package:flutter/material.dart';

import '../../../models/delivery_status.dart';
import '../../../services/background_tracking_service.dart';
import '../../../services/location_gate.dart';

class CarrierDeliveriesAutoTracker {
  static Set<String> extractTrackingDeliveryIds(Iterable<Map<String, dynamic>> deliveries) {
    final ids = <String>{};
    for (final d in deliveries) {
      final id = d['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      final status = d['status']?.toString().toLowerCase() ?? '';
      final shouldTrack = status == DeliveryStatus.inTransit || status == DeliveryStatus.atDoor;
      if (shouldTrack) ids.add(id);
    }
    return ids;
  }

  static Future<void> syncFromDeliveries(
    Iterable<Map<String, dynamic>> deliveries, {
    BuildContext? context,
    bool userInitiated = false,
  }) async {
    final ids = extractTrackingDeliveryIds(deliveries);
    if (ids.isEmpty) {
      await BackgroundTrackingService.syncDeliveries(<String>{});
      return;
    }

    final ok = await LocationGate.ensureReady(
      context: context,
      userInitiated: userInitiated,
    );

    if (!ok) {
      // Don't keep the background service running without permission.
      await BackgroundTrackingService.syncDeliveries(<String>{});
      return;
    }

    await BackgroundTrackingService.syncDeliveries(ids);
  }
}
