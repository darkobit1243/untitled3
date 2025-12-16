/// Centralized access to Google API keys used for REST endpoints (Places/Directions/Geocode).
///
/// Configure at build/run time via:
/// `--dart-define=GOOGLE_MAPS_WEB_API_KEY=YOUR_KEY`
class GoogleApiKeys {
  static const String mapsWebApiKey = String.fromEnvironment('GOOGLE_MAPS_WEB_API_KEY');
}
