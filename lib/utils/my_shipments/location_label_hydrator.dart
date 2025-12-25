import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/google_places_service.dart';
import '../../services/location_label_cache.dart';
import 'merge_my_shipments_data.dart';

class MyShipmentsLocationLabelHydrator {
  MyShipmentsLocationLabelHydrator({required GooglePlacesService places}) : _places = places;

  final GooglePlacesService _places;
  final Map<String, String> _locationLabelCache = <String, String>{};
  final Set<String> _locationLabelInFlight = <String>{};

  Future<void> hydrateAddressLabels({
    required List<dynamic> items,
    required int runId,
    required int Function() currentRunId,
    required bool Function() isMounted,
    required void Function() requestRebuild,
  }) async {
    final seen = <String>{};

    // Sequential requests to avoid hammering Geocoding API.
    var anyUpdates = false;
    var updatesSinceLastSetState = 0;

    for (final entry in items) {
      if (!isMounted() || runId != currentRunId()) return;
      if (entry is! Map) continue;
      final type = entry['type']?.toString();
      final data = entry['data'];
      final dataMap = asStringMap(data);
      if (dataMap == null) continue;

      Map<String, dynamic>? listing;
      if (type == 'listing') {
        listing = dataMap;
      } else if (type == 'delivery') {
        listing = asStringMap(dataMap['listing']);
      }
      if (listing == null) continue;

      final listingId = listing['id']?.toString() ?? dataMap['listingId']?.toString();
      final pickupSeenKey = '${listingId ?? ''}::pickup_location';
      final dropoffSeenKey = '${listingId ?? ''}::dropoff_location';

      bool pickupUpdated = false;
      bool dropoffUpdated = false;

      if (!seen.contains(pickupSeenKey)) {
        seen.add(pickupSeenKey);
        pickupUpdated = await _ensureLocationLabel(
          listingId: listingId,
          listing: listing,
          locationKey: 'pickup_location',
          isMounted: isMounted,
        );
      }

      if (!seen.contains(dropoffSeenKey)) {
        seen.add(dropoffSeenKey);
        dropoffUpdated = await _ensureLocationLabel(
          listingId: listingId,
          listing: listing,
          locationKey: 'dropoff_location',
          isMounted: isMounted,
        );
      }

      if (!isMounted() || runId != currentRunId()) return;
      final updatedCount = (pickupUpdated ? 1 : 0) + (dropoffUpdated ? 1 : 0);
      if (updatedCount > 0) {
        anyUpdates = true;
        updatesSinceLastSetState += updatedCount;
        // Batch redraws to avoid jank while still letting labels appear progressively.
        if (updatesSinceLastSetState >= 6) {
          requestRebuild();
          updatesSinceLastSetState = 0;
        }
      }
    }

    if (!isMounted() || runId != currentRunId()) return;
    if (anyUpdates && updatesSinceLastSetState > 0) {
      requestRebuild();
    }
  }

  Future<bool> _ensureLocationLabel({
    required String? listingId,
    required Map<String, dynamic> listing,
    required String locationKey,
    required bool Function() isMounted,
  }) async {
    final loc = asStringMap(listing[locationKey]);
    if (loc == null) return false;

    final existing = (loc['display'] ?? loc['address'])?.toString() ?? '';
    if (existing.trim().isNotEmpty) return false;

    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return false;

    final key = '${listingId ?? ''}|$locationKey|${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    final cached = _locationLabelCache[key];
    if (cached != null && cached.trim().isNotEmpty) {
      loc['display'] = cached;
      loc['address'] = cached;
      listing[locationKey] = loc;
      return true;
    }

    final persisted = await LocationLabelCache.getLabel(lat: lat, lng: lng);
    if (persisted != null && persisted.trim().isNotEmpty) {
      loc['display'] = persisted;
      loc['address'] = persisted;
      listing[locationKey] = loc;
      return true;
    }

    if (_locationLabelInFlight.contains(key)) return false;
    _locationLabelInFlight.add(key);
    try {
      final parts = await _places.reverseGeocodeParts(position: LatLng(lat, lng));
      final label = parts?.toDisplayString();
      if (!isMounted()) return false;
      if (label == null || label.trim().isEmpty) return false;

      // Persist across restarts.
      // ignore: unawaited_futures
      LocationLabelCache.setLabel(lat: lat, lng: lng, label: label);

      _locationLabelCache[key] = label;
      loc['display'] = label;
      loc['address'] = label;
      listing[locationKey] = loc;

      return true;
    } catch (_) {
      // ignore
    } finally {
      _locationLabelInFlight.remove(key);
    }

    return false;
  }
}
