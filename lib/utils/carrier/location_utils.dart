import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationUtils {
  const LocationUtils._();

  static double? distanceKmToPickup({
    required Map<String, dynamic> listing,
    required Position? current,
  }) {
    if (current == null) return null;
    final pickup = listing['pickup_location'];
    if (pickup is! Map<String, dynamic>) return null;
    final lat = (pickup['lat'] as num?)?.toDouble();
    final lng = (pickup['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(current.latitude, current.longitude, lat, lng) / 1000;
  }

  static LatLng? latLngFromLocation(dynamic location) {
    if (location is! Map) return null;
    final lat = (location['lat'] as num?)?.toDouble();
    final lng = (location['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  static LatLngBounds boundsFromTwoPoints(LatLng a, LatLng b) {
    final southWest = LatLng(
      a.latitude < b.latitude ? a.latitude : b.latitude,
      a.longitude < b.longitude ? a.longitude : b.longitude,
    );
    final northEast = LatLng(
      a.latitude > b.latitude ? a.latitude : b.latitude,
      a.longitude > b.longitude ? a.longitude : b.longitude,
    );
    return LatLngBounds(southwest: southWest, northeast: northEast);
  }

  /// Correct Google Maps directions URL (properly encoded query params).
  /// Example: https://www.google.com/maps/dir/?api=1&origin=...&destination=...
  static Uri googleMapsDirectionsUri({
    LatLng? origin,
    required LatLng destination,
    String travelMode = 'driving',
  }) {
    final params = <String, String>{
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': travelMode,
    };
    if (origin != null) {
      params['origin'] = '${origin.latitude},${origin.longitude}';
    }

    return Uri.https('www.google.com', '/maps/dir/', params);
  }
}
