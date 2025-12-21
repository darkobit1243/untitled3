import 'package:shared_preferences/shared_preferences.dart';

/// Persistent cache for reverse-geocoded location labels.
///
/// Stores labels keyed by rounded lat/lng so the app does not repeatedly call
/// Google Geocoding for the same coordinates.
class LocationLabelCache {
  static const String _prefix = 'geo_label_v1:';
  static const Duration _ttl = Duration(days: 30);

  static final Map<String, String> _memory = <String, String>{};

  static String _key(double lat, double lng) {
    // 5 decimals ~ 1.1m; good enough for address labels and dedup.
    final la = lat.toStringAsFixed(5);
    final lo = lng.toStringAsFixed(5);
    return '$_prefix$la,$lo';
  }

  static Future<String?> getLabel({required double lat, required double lng}) async {
    final key = _key(lat, lng);
    final mem = _memory[key];
    if (mem != null && mem.trim().isNotEmpty) return mem;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;

    // Format: <millis>|<label>
    final sep = raw.indexOf('|');
    if (sep <= 0) {
      // Backwards/invalid entry: treat as plain label.
      final label = raw.trim();
      if (label.isEmpty) return null;
      _memory[key] = label;
      return label;
    }

    final tsStr = raw.substring(0, sep);
    final label = raw.substring(sep + 1).trim();
    if (label.isEmpty) {
      await prefs.remove(key);
      return null;
    }

    final ts = int.tryParse(tsStr);
    if (ts == null) {
      _memory[key] = label;
      return label;
    }

    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (age > _ttl) {
      await prefs.remove(key);
      return null;
    }

    _memory[key] = label;
    return label;
  }

  static Future<void> setLabel({required double lat, required double lng, required String label}) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;

    final key = _key(lat, lng);
    _memory[key] = trimmed;

    final prefs = await SharedPreferences.getInstance();
    final ts = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(key, '$ts|$trimmed');
  }
}
