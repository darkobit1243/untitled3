import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../services/google_places_service.dart';
import '../../../services/location_label_cache.dart';

typedef ListingLocationLabelCallback = void Function({
  required String listingId,
  required String locationKey,
  required String label,
});

class ListingLocationLabelHydrator {
  ListingLocationLabelHydrator({required GooglePlacesService places}) : _places = places;

  final GooglePlacesService _places;

  final Map<String, String> _pickupLabels = <String, String>{};
  final Map<String, String> _dropoffLabels = <String, String>{};
  final Set<String> _inFlight = <String>{};

  Future<void> hydrateListingAddresses({
    required List<Map<String, dynamic>> listings,
    required int runId,
    required int Function() currentRunId,
    required bool Function() isMounted,
    required ListingLocationLabelCallback onLabel,
  }) async {
    // Sequential requests to avoid hammering Geocoding API.
    for (final item in listings) {
      if (!isMounted() || runId != currentRunId()) return;
      final listingId = item['id']?.toString();
      if (listingId == null || listingId.isEmpty) continue;

      await _ensureLocationLabel(
        listing: item,
        listingId: listingId,
        locationKey: 'pickup_location',
        cache: _pickupLabels,
        runId: runId,
        currentRunId: currentRunId,
        isMounted: isMounted,
        onLabel: onLabel,
      );

      await _ensureLocationLabel(
        listing: item,
        listingId: listingId,
        locationKey: 'dropoff_location',
        cache: _dropoffLabels,
        runId: runId,
        currentRunId: currentRunId,
        isMounted: isMounted,
        onLabel: onLabel,
      );
    }
  }

  Future<void> _ensureLocationLabel({
    required Map<String, dynamic> listing,
    required String listingId,
    required String locationKey,
    required Map<String, String> cache,
    required int runId,
    required int Function() currentRunId,
    required bool Function() isMounted,
    required ListingLocationLabelCallback onLabel,
  }) async {
    final inflightKey = '$listingId::$locationKey';
    if (cache.containsKey(listingId)) return;
    if (_inFlight.contains(inflightKey)) return;

    final locRaw = listing[locationKey];
    if (locRaw is! Map) return;
    final lat = (locRaw['lat'] as num?)?.toDouble();
    final lng = (locRaw['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    final persisted = await LocationLabelCache.getLabel(lat: lat, lng: lng);
    if (!isMounted() || runId != currentRunId()) return;

    if (persisted != null && persisted.trim().isNotEmpty) {
      cache[listingId] = persisted;
      onLabel(listingId: listingId, locationKey: locationKey, label: persisted);
      return;
    }

    _inFlight.add(inflightKey);
    try {
      final parts = await _places.reverseGeocodeParts(position: LatLng(lat, lng));
      final label = parts?.toDisplayString();
      if (!isMounted() || runId != currentRunId()) return;
      if (label == null || label.trim().isEmpty) return;

      // Persist across restarts.
      // ignore: unawaited_futures
      LocationLabelCache.setLabel(lat: lat, lng: lng, label: label);

      cache[listingId] = label;
      onLabel(listingId: listingId, locationKey: locationKey, label: label);
    } catch (_) {
      // ignore
    } finally {
      _inFlight.remove(inflightKey);
    }
  }
}

List<Map<String, dynamic>>? applyLocationLabelToListings({
  required List<Map<String, dynamic>> listings,
  required String listingId,
  required String locationKey,
  required String label,
}) {
  final idx = listings.indexWhere((e) => e['id']?.toString() == listingId);
  if (idx < 0) return null;

  final listing = Map<String, dynamic>.from(listings[idx]);
  final locRaw = listing[locationKey];
  if (locRaw is! Map) return null;

  final loc = Map<String, dynamic>.from(locRaw.map((k, v) => MapEntry(k.toString(), v)));
  final display = loc['display']?.toString();
  if (display != null && display.trim().isNotEmpty) return null;

  loc['display'] = label;
  final addr = loc['address']?.toString();
  if (addr == null || addr.trim().isEmpty) {
    loc['address'] = label;
  }

  listing[locationKey] = loc;
  final next = List<Map<String, dynamic>>.from(listings);
  next[idx] = listing;
  return next;
}
