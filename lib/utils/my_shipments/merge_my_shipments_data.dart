import '../../models/delivery_status.dart';

Map<String, dynamic>? asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}

class MyShipmentsMergedData {
  MyShipmentsMergedData({
    required this.activeItems,
    required this.historyItems,
    required this.ratedDeliveryIds,
  });

  final List<dynamic> activeItems;
  final List<dynamic> historyItems;
  final Set<String> ratedDeliveryIds;
}

MyShipmentsMergedData mergeMyShipmentsData({
  required List<dynamic> listingsData,
  required List<dynamic> deliveriesData,
  required List<dynamic> mineRatings,
}) {
  final listingById = <String, Map<String, dynamic>>{};
  for (final l in listingsData) {
    final lm = asStringMap(l);
    final id = lm?['id']?.toString() ?? '';
    if (id.isEmpty || lm == null) continue;
    listingById[id] = lm;
  }

  final deliveryByListingId = <String, Map<String, dynamic>>{};
  for (final d in deliveriesData) {
    final dm = asStringMap(d);
    if (dm == null) continue;
    final listingId = dm['listingId']?.toString() ?? asStringMap(dm['listing'])?['id']?.toString() ?? '';
    if (listingId.isEmpty) continue;

    // Some backend endpoints may not include embedded listing; attach it from my listings.
    dm['listing'] ??= listingById[listingId];

    deliveryByListingId.putIfAbsent(listingId, () => dm);
  }

  final active = <dynamic>[];
  final history = <dynamic>[];

  final consumedDeliveryListingIds = <String>{};

  // Add listings (or their merged delivery card if accepted)
  for (final listing in listingsData) {
    final listingMap = asStringMap(listing);
    final listingId = listingMap?['id']?.toString() ?? '';

    if (listingId.isNotEmpty) {
      final delivery = deliveryByListingId[listingId];
      if (delivery != null) {
        final status = delivery['status']?.toString().toLowerCase() ?? '';
        if (status == DeliveryStatus.inTransit || status == DeliveryStatus.pickupPending || status == DeliveryStatus.atDoor) {
          active.add({'type': 'delivery', 'data': delivery});
        } else {
          history.add({'type': 'delivery', 'data': delivery});
        }
        consumedDeliveryListingIds.add(listingId);
        continue;
      }
    }

    // No accepted delivery yet -> keep as a normal listing row.
    active.add({'type': 'listing', 'data': listing});
  }

  // Add deliveries that are not linked to any fetched listing (edge-case) to avoid losing them.
  for (final delivery in deliveriesData) {
    final dm = asStringMap(delivery);
    if (dm == null) {
      history.add({'type': 'delivery', 'data': delivery});
      continue;
    }
    final listingId = dm['listingId']?.toString() ?? asStringMap(dm['listing'])?['id']?.toString() ?? '';

    if (listingId.isNotEmpty) {
      dm['listing'] ??= listingById[listingId];
    }

    if (listingId.isNotEmpty && consumedDeliveryListingIds.contains(listingId)) {
      continue;
    }
    final status = dm['status']?.toString().toLowerCase() ?? '';
    if (status == DeliveryStatus.inTransit || status == DeliveryStatus.pickupPending || status == DeliveryStatus.atDoor) {
      active.add({'type': 'delivery', 'data': dm});
    } else {
      history.add({'type': 'delivery', 'data': dm});
    }
  }

  // Fetch current user's given ratings once; used to hide "Puan Ver".
  final ratedIds = <String>{};
  for (final r in mineRatings) {
    if (r is Map) {
      final deliveryId = r['deliveryId']?.toString() ?? '';
      if (deliveryId.isNotEmpty) ratedIds.add(deliveryId);
    }
  }

  return MyShipmentsMergedData(
    activeItems: active,
    historyItems: history,
    ratedDeliveryIds: ratedIds,
  );
}
