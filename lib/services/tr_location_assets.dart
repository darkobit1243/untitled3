import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class TrCity {
  const TrCity({required this.id, required this.name});

  final String id;
  final String name;
}

class TrDistrict {
  const TrDistrict({required this.id, required this.cityId, required this.name});

  final String id;
  final String cityId;
  final String name;
}

class TrLocationData {
  const TrLocationData({required this.cities, required this.districts});

  final List<TrCity> cities;
  final List<TrDistrict> districts;
}

class TrLocationAssets {
  static TrLocationData? _cache;

  static Future<TrLocationData> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final citiesRaw = await rootBundle.loadString('assets/data/il.json');
    final districtsRaw = await rootBundle.loadString('assets/data/ilce.json');

    final cities = _parseCities(citiesRaw);
    final districts = _parseDistricts(districtsRaw);

    final data = TrLocationData(cities: cities, districts: districts);
    _cache = data;
    return data;
  }

  static List<TrCity> _parseCities(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('il.json root is not a List');
    }

    final table = decoded.cast<dynamic>().firstWhere(
          (e) => e is Map && e['type'] == 'table' && e['name'] == 'il' && e['data'] is List,
          orElse: () => null,
        );

    if (table is! Map || table['data'] is! List) {
      throw const FormatException('il.json table not found');
    }

    final rows = (table['data'] as List).whereType<Map>();
    final cities = <TrCity>[];
    for (final row in rows) {
      final id = row['id']?.toString();
      final name = row['name']?.toString();
      if (id == null || name == null) continue;
      cities.add(TrCity(id: id, name: name));
    }

    cities.sort((a, b) => a.name.compareTo(b.name));
    return cities;
  }

  static List<TrDistrict> _parseDistricts(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('ilce.json root is not a List');
    }

    final table = decoded.cast<dynamic>().firstWhere(
          (e) => e is Map && e['type'] == 'table' && e['name'] == 'ilce' && e['data'] is List,
          orElse: () => null,
        );

    if (table is! Map || table['data'] is! List) {
      throw const FormatException('ilce.json table not found');
    }

    final rows = (table['data'] as List).whereType<Map>();
    final districts = <TrDistrict>[];
    for (final row in rows) {
      final id = row['id']?.toString();
      final cityId = row['il_id']?.toString();
      final name = row['name']?.toString();
      if (id == null || cityId == null || name == null) continue;
      districts.add(TrDistrict(id: id, cityId: cityId, name: name));
    }

    districts.sort((a, b) {
      final cmp = a.cityId.compareTo(b.cityId);
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });

    return districts;
  }
}
