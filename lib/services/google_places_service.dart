import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'google_api_keys.dart';

class GooglePlacesService {
  GooglePlacesService(this._dio);

  final Dio _dio;

  String _requireApiKey() {
    final key = GoogleApiKeys.mapsWebApiKey;
    if (key.isEmpty) {
      throw StateError(
        'Missing GOOGLE_MAPS_WEB_API_KEY. Pass it at run/build time via '
        '--dart-define=GOOGLE_MAPS_WEB_API_KEY=YOUR_KEY or '
        '--dart-define-from-file=dart_defines.json. '
        'Note: hot restart/hot reload will NOT pick up new dart-defines; '
        'stop the app and run again.',
      );
    }
    assert(() {
      // Debug-only: helps verify which key is compiled into the app.
      // Do not log the full key.
      // ignore: avoid_print
      print('GOOGLE_MAPS_WEB_API_KEY=${GoogleApiKeys.mapsWebApiKeyMasked}');
      return true;
    }());
    return key;
  }

  Future<List<dynamic>> autocomplete({
    required String input,
    LatLng? location,
    int radiusMeters = 50000,
    bool strictBounds = true,
    String types = 'geocode',
    String language = 'tr',
    String components = 'country:tr',
    CancelToken? cancelToken,
  }) async {
    try {
      final apiKey = _requireApiKey();
      // Places API (New)
      // https://places.googleapis.com/v1/places:autocomplete
      // Keep a legacy-like result shape for the existing UI:
      // [{"description": "...", "place_id": "..."}]

      String? regionCode;
      if (components.trim().isNotEmpty) {
        // Expected format: country:tr
        final parts = components.split(':');
        if (parts.length == 2 && parts.first.trim().toLowerCase() == 'country') {
          regionCode = parts.last.trim().toUpperCase();
        }
      }

      final body = <String, dynamic>{
        'input': input,
        'languageCode': language,
        if (regionCode != null && regionCode.isNotEmpty) 'regionCode': regionCode,
      };

      if (location != null) {
        final clampedRadiusMeters = radiusMeters < 0
            ? 0
            : (radiusMeters > 50000 ? 50000 : radiusMeters);
        final circle = <String, dynamic>{
          'center': <String, dynamic>{
            'latitude': location.latitude,
            'longitude': location.longitude,
          },
          'radius': clampedRadiusMeters.toDouble(),
        };
        if (strictBounds) {
          body['locationRestriction'] = <String, dynamic>{'circle': circle};
        } else {
          body['locationBias'] = <String, dynamic>{'circle': circle};
        }
      }

      final response = await _dio.post(
        'https://places.googleapis.com/v1/places:autocomplete',
        data: body,
        options: Options(
          headers: <String, dynamic>{
            'X-Goog-Api-Key': apiKey,
            // Only request fields we need.
            'X-Goog-FieldMask':
                'suggestions.placePrediction.placeId,'
                'suggestions.placePrediction.text.text,'
                'suggestions.placePrediction.structuredFormat.mainText.text,'
                'suggestions.placePrediction.structuredFormat.secondaryText.text',
          },
        ),
        cancelToken: cancelToken,
      );

      final data = _asMap(response.data);
      final suggestions = data['suggestions'];
      if (suggestions is! List) return const [];

      final out = <Map<String, dynamic>>[];
      for (final s in suggestions) {
        if (s is! Map) continue;
        final pp = s['placePrediction'];
        if (pp is! Map) continue;
        final placeId = pp['placeId']?.toString();
        if (placeId == null || placeId.trim().isEmpty) continue;

        String description = '';
        final structured = pp['structuredFormat'];
        if (structured is Map) {
          final mainText = (structured['mainText'] as Map?)?['text']?.toString();
          final secondaryText = (structured['secondaryText'] as Map?)?['text']?.toString();
          final m = mainText?.trim();
          final s2 = secondaryText?.trim();
          if (m != null && m.isNotEmpty && s2 != null && s2.isNotEmpty) {
            description = '$m, $s2';
          } else if (m != null && m.isNotEmpty) {
            description = m;
          }
        }
        if (description.trim().isEmpty) {
          final t = (pp['text'] as Map?)?['text']?.toString();
          description = t?.trim() ?? '';
        }

        out.add(<String, dynamic>{
          'place_id': placeId,
          'description': description,
        });
      }
      return out;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return const [];
      final statusCode = e.response?.statusCode;
      final data = _asMap(e.response?.data);
      final error = data['error'];
      final message = (error is Map ? error['message'] : null)?.toString() ?? e.message;
      throw GooglePlacesApiException(
        status: statusCode == null ? 'HTTP_ERROR' : 'HTTP_$statusCode',
        message: message,
      );
    } catch (_) {
      rethrow;
    }
  }

  Future<LatLng?> placeLatLng({
    required String placeId,
    CancelToken? cancelToken,
  }) async {
    try {
      final apiKey = _requireApiKey();
      // Places API (New) Place Details
      // https://places.googleapis.com/v1/places/{placeId}
      final response = await _dio.get(
        'https://places.googleapis.com/v1/places/$placeId',
        options: Options(
          headers: <String, dynamic>{
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask': 'location',
          },
        ),
        cancelToken: cancelToken,
      );

      final data = _asMap(response.data);
      final location = data['location'] as Map<String, dynamic>?;
      if (location == null) return null;

      final lat = (location['latitude'] as num?)?.toDouble();
      final lng = (location['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      return LatLng(lat, lng);
    } catch (_) {
      return null;
    }
  }

  Future<String?> reverseGeocode({
    required LatLng position,
    String language = 'tr',
    CancelToken? cancelToken,
  }) async {
    try {
      final apiKey = _requireApiKey();
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: <String, dynamic>{
          'latlng': '${position.latitude},${position.longitude}',
          'key': apiKey,
          'language': language,
        },
        cancelToken: cancelToken,
      );

      final data = _asMap(response.data);
      final status = data['status']?.toString();
      if (status != null && status != 'OK') return null;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;
      return results.first['formatted_address']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<GeocodedAddressParts?> reverseGeocodeParts({
    required LatLng position,
    String language = 'tr',
    CancelToken? cancelToken,
  }) async {
    try {
      final apiKey = _requireApiKey();
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: <String, dynamic>{
          'latlng': '${position.latitude},${position.longitude}',
          'key': apiKey,
          'language': language,
        },
        cancelToken: cancelToken,
      );

      final data = _asMap(response.data);
      final status = data['status']?.toString();
      if (status != null && status != 'OK') return null;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final first = results.first;
      if (first is! Map) return null;
      final components = first['address_components'];
      if (components is! List) return null;

      String? street;
      String? neighborhood;
      String? district;
      String? city;

      for (final c in components) {
        if (c is! Map) continue;
        final typesRaw = c['types'];
        if (typesRaw is! List) continue;
        final types = typesRaw.map((e) => e.toString()).toSet();
        final longName = c['long_name']?.toString();
        if (longName == null || longName.trim().isEmpty) continue;

        if (street == null && types.contains('route')) {
          street = longName;
          continue;
        }

        if (neighborhood == null && types.contains('neighborhood')) {
          neighborhood = longName;
          continue;
        }

        if (neighborhood == null && (types.contains('sublocality_level_1') || types.contains('sublocality'))) {
          neighborhood = longName;
          continue;
        }

        if (district == null && types.contains('administrative_area_level_2')) {
          district = longName;
          continue;
        }

        if (city == null && types.contains('administrative_area_level_1')) {
          city = longName;
          continue;
        }
      }

      if (street == null && neighborhood == null && district == null && city == null) return null;
      return GeocodedAddressParts(
        street: street,
        neighborhood: neighborhood,
        district: district,
        city: city,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    // Dio may sometimes return LinkedHashMap<dynamic, dynamic>
    if (data is Map) return data.map((k, v) => MapEntry(k.toString(), v));
    return const <String, dynamic>{};
  }
}

class GooglePlacesApiException implements Exception {
  GooglePlacesApiException({
    required this.status,
    this.message,
  });

  final String status;
  final String? message;

  @override
  String toString() {
    final m = message;
    if (m == null || m.trim().isEmpty) return 'GooglePlacesApiException($status)';
    return 'GooglePlacesApiException($status): $m';
  }
}

class GeocodedAddressParts {
  const GeocodedAddressParts({
    required this.street,
    required this.neighborhood,
    required this.district,
    required this.city,
  });

  final String? street;
  final String? neighborhood;
  final String? district;
  final String? city;

  String toDisplayString() {
    final parts = <String>[];
    if (street != null && street!.trim().isNotEmpty) parts.add(street!.trim());
    if (neighborhood != null && neighborhood!.trim().isNotEmpty) parts.add(neighborhood!.trim());

    final admin = <String>[];
    if (district != null && district!.trim().isNotEmpty) admin.add(district!.trim());
    if (city != null && city!.trim().isNotEmpty) admin.add(city!.trim());
    if (admin.isNotEmpty) parts.add(admin.join(' / '));

    return parts.join(', ');
  }
}
