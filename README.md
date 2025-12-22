# untitled

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Google API Key (Places/Directions/Geocode)

Bu projede bazı ekranlar Google Places/Directions/Geocode REST endpoint’lerini çağırır.
API key repo içine gömülü değildir; çalıştırırken `--dart-define` ile verilir:

- `flutter run --dart-define=GOOGLE_MAPS_WEB_API_KEY=YOUR_KEY`

VS Code ile daha rahat kullanım (önerilen):

- Repo kökünde `dart_defines.example.json` dosyasını `dart_defines.json` olarak kopyala.
- `dart_defines.json` içine `GOOGLE_MAPS_WEB_API_KEY` değerini yaz.
- VS Code debug config `.vscode/launch.json` zaten `--dart-define-from-file=dart_defines.json` kullanır.

Not: Key’i Google Cloud Console’da mümkün olduğunca kısıtlayın (API bazında ve uygulama/bundle bazında).

## iOS: Google Maps SDK Key (Harita görünmüyor sorunu)

iPhone/iPad’de haritanın görünmesi için iOS tarafında ayrıca Google Maps SDK key verilmesi gerekir.
Bu repo içinde iOS native tarafı `Info.plist` üzerinden `GMSApiKey` okur.

- `ios/Flutter/Debug.xcconfig` ve `ios/Flutter/Release.xcconfig` içinde `GOOGLE_MAPS_IOS_API_KEY` değerini set edin.
- Google Cloud Console’da **Maps SDK for iOS** etkin olmalı ve key mümkünse iOS bundle id ile kısıtlanmalı.
