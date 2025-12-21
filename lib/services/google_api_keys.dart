/// Centralized access to Google API keys used for REST endpoints (Places/Directions/Geocode).
///
/// Configure at build/run time via:
/// `--dart-define=GOOGLE_MAPS_WEB_API_KEY=YOUR_KEY`
class GoogleApiKeys {
  // Important: This key is used for Google Web Service REST endpoints
  // (Places/Geocode/Directions). Do NOT reuse the Android Maps SDK key from
  // AndroidManifest.xml here, because that key is commonly restricted to
  // Android apps and will cause REQUEST_DENIED for REST calls.
  // Note: We keep a defaultValue fallback to reduce run-configuration issues
  // during development (e.g., running without --dart-define-from-file).
  // If you pass --dart-define(-from-file), it overrides this value.
  static const String mapsWebApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_WEB_API_KEY',
    defaultValue: 'AIzaSyDLxHgPlQ0PZ6NsdYhIhIlcQ6YN_WGYuVg',
  );

  static String get mapsWebApiKeyMasked {
    final key = mapsWebApiKey;
    if (key.isEmpty) return '(empty)';
    if (key.length <= 10) return '***';
    return '${key.substring(0, 6)}…${key.substring(key.length - 4)}';
  }
}
