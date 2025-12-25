import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Basit kargo-backend HTTP istemcisi.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  bool enableLogging = false;

  /// Backend base URL.
  ///
  /// Default: Railway production.
  /// Override (e.g. local): pass `--dart-define=API_BASE_URL=http://10.0.2.2:3000`
  /// (Android emulator) or your machine IP.
  static const String _defaultBaseUrl = 'https://kargo-backend-production.up.railway.app';
  String get _baseUrl => const String.fromEnvironment('API_BASE_URL', defaultValue: _defaultBaseUrl);

  String? _jwt;
  String? _refreshToken;
  String? _userId;
    static const String _authTokenKey = 'auth_token';
    static const String _refreshTokenKey = 'refresh_token';
  IO.Socket? _socket;
  final List<void Function(bool)> _socketStatusListeners = [];

  static const String _listingsCacheKey = 'listings_cache_v1';
  static const String _listingsCacheAtKey = 'listings_cache_at_v1';
  static const Duration _listingsMemoryTtl = Duration(seconds: 20);
  static const Duration _listingsDiskTtl = Duration(minutes: 5);

  List<dynamic>? _listingsCache;
  DateTime? _listingsCacheAt;
  Future<List<dynamic>>? _listingsInFlight;

  /// Public auth helpers for other services
  Map<String, String> authHeaders() => _headers();
  String get baseUrl => _baseUrl;
  Future<String?> getAuthToken() async {
    if (_jwt != null) return _jwt;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey);
  }

  void _log(String message) {
    if (enableLogging) {
      // ignore: avoid_print
      print(message);
    }
  }

  void setToken(String token) {
    // Token değişince kullanıcı cache'leri resetlenmeli; aksi halde eski _userId
    // ile /listings/owner, /offers/owner, /deliveries/by-owner gibi endpointler 403 dönebilir.
    if (_jwt != token) {
      _jwt = token;
      _userId = null;

      // Socket header'ı da token'a bağlı; yeniden bağlanmak için kapat.
      try {
        _socket?.disconnect();
        _socket?.dispose();
      } catch (_) {}
      _socket = null;
    }
    _persistToken(token);
  }

  void setSession({required String token, String? refreshToken}) {
    setToken(token);
    final rt = refreshToken?.trim();
    if (rt != null && rt.isNotEmpty) {
      _refreshToken = rt;
      // ignore: unawaited_futures
      _persistRefreshToken(rt);
    }
  }

  Future<void> registerFcmToken(String? token) async {
    if (_jwt == null) {
      final restored = await tryRestoreSession();
      if (!restored) return;
    }
    final resp = await _client.post(
      Uri.parse('$_baseUrl/auth/fcm-token'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{'token': token}),
    );
    if (resp.statusCode >= 400) {
      throw Exception('FCM token kaydedilemedi: ${resp.body}');
    }
  }

  Future<void> _persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
  }

  Future<void> _persistRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('preferred_role');
  }

  Future<void> clearToken() async {
    _jwt = null;
    _refreshToken = null;
    _userId = null;
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove('preferred_role');
  }

  Future<bool> refreshSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rt = (_refreshToken ?? prefs.getString(_refreshTokenKey))?.trim();
    if (rt == null || rt.isEmpty) return false;

    final resp = await _client.post(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: _publicHeaders(),
      body: jsonEncode(<String, dynamic>{'refreshToken': rt}),
    );
    if (resp.statusCode >= 400) {
      await clearToken();
      return false;
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = (data['token'] as String?)?.trim();
    final newRt = (data['refreshToken'] as String?)?.trim();
    if (token == null || token.isEmpty) {
      await clearToken();
      return false;
    }

    setSession(token: token, refreshToken: newRt);
    return true;
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_jwt != null) {
      headers['Authorization'] = 'Bearer $_jwt';
    }
    return headers;
  }

  Map<String, String> _publicHeaders() {
    return const <String, String>{
      'Content-Type': 'application/json',
    };
  }

  // AUTH
  Future<void> register(String email, String password, {required String role, Map<String, dynamic>? profile}) async {
    final payload = {
      'email': email,
      'password': password,
      'role': role,
    };
    if (profile != null) {
      for (final entry in profile.entries) {
        final value = entry.value;
        if (value == null) continue;
        if (value is String && value.trim().isEmpty) continue;
        payload[entry.key] = value;
      }
    }

    final resp = await _client.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Kayıt başarısız: ${resp.body}');
    }

    // Backend artık register'da token + role dönüyor
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = data['token'] as String;
    final refreshToken = data['refreshToken'] as String?;
    final r = (data['role'] as String?) ?? role;
    setSession(token: token, refreshToken: refreshToken);
    await setPreferredRole(r);
  }

  /// SMS doğrulama (Firebase Phone Auth) sonrası backend'e kayıt.
  ///
  /// Backend, `Authorization: Bearer <firebase_id_token>` ile gelen Firebase ID token'ı doğrular;
  /// doğrulama başarılıysa kullanıcıyı DB'ye kaydeder ve kendi JWT token'ını döner.
  Future<void> registerWithFirebaseIdToken(
    String firebaseIdToken, {
    required String role,
    required String password,
    required Map<String, dynamic> profile,
    String? email,
  }) async {
    final payload = <String, dynamic>{
      'role': role,
      'password': password,
    };

    if (email != null && email.trim().isNotEmpty) {
      payload['email'] = email.trim();
    }

    // Profile alanlarını payload'a merge et (fullName, address, vehicleType, ...)
    for (final entry in profile.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      payload[entry.key] = value;
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $firebaseIdToken',
    };

    final resp = await _client.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Kayıt başarısız: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = data['token'] as String;
    final refreshToken = data['refreshToken'] as String?;
    final r = (data['role'] as String?) ?? role;
    setSession(token: token, refreshToken: refreshToken);
    await setPreferredRole(r);
  }

  Future<String> login(String email, String password) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (enableLogging || kDebugMode) {
      // ignore: avoid_print
      print('LOGIN RESPONSE: ${resp.statusCode} ${resp.body}');
    }

    if (resp.statusCode >= 400) {
      throw Exception('Giriş başarısız: ${resp.statusCode} - ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = data['token'] as String;
    final refreshToken = data['refreshToken'] as String?;
    final r = data['role'] as String?; // sender|carrier
    setSession(token: token, refreshToken: refreshToken);
    if (r != null) {
      await setPreferredRole(r);
    } else {
      // Bazı backend sürümlerinde login response'unda role dönmeyebilir.
      // Token set edildikten sonra /auth/me ile role'u çekip local'e yaz.
      try {
        await _getUserIdAndRole();
      } catch (_) {
        // ignore: login başarılı; role default'u sender kalır.
      }
    }
    return token;
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/auth/forgot-password'),
      headers: _publicHeaders(),
      body: jsonEncode({'email': email}),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Şifre sıfırlama isteği başarısız: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'ok': true};
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/auth/reset-password'),
      headers: _publicHeaders(),
      body: jsonEncode({'email': email, 'code': code, 'newPassword': newPassword}),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Şifre güncellenemedi: ${resp.body}');
    }
  }

  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_authTokenKey);
    if (token == null) return false;
    _jwt = token;
    _refreshToken = prefs.getString(_refreshTokenKey);
    try {
      await _getUserIdAndRole();
      return true;
    } catch (e) {
      // Don't log the user out on transient network/SSL failures.
      // Only clear the token if the backend clearly rejected it.
      final msg = e.toString();
      final looksUnauthorized = msg.contains('401') || msg.contains('403') || msg.contains('Unauthorized');
      if (looksUnauthorized) {
        final refreshed = await refreshSession();
        if (!refreshed) return false;
        try {
          await _getUserIdAndRole();
          return true;
        } catch (_) {
          await clearToken();
          return false;
        }
      }

      // Keep the stored token; app may be offline or backend unreachable.
      // Subsequent calls can retry /auth/me.
      return true;
    }
  }

  Future<String> _getUserIdAndRole() async {
    if (_userId != null) return _userId!;

    final resp = await _client.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Kullanıcı bilgisi alınamadı: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final idValue = data['sub'] ?? data['id'];
    if (idValue == null) {
      throw Exception('Kullanıcı bilgisi eksik');
    }
    final id = idValue.toString();
    _userId = id;
    final role = data['role'] as String?;
    if (role != null) {
      await setPreferredRole(role);
    }
    return id;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final resp = await _client.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Profil bilgisi alınamadı: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMyProfile({
    String? avatarUrl,
    Map<String, dynamic>? profile,
  }) async {
    final payload = <String, dynamic>{};
    if (avatarUrl != null) {
      payload['avatarUrl'] = avatarUrl;
    }

    if (profile != null) {
      for (final entry in profile.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value == null) {
          payload[key] = null;
          continue;
        }
        if (value is String) {
          payload[key] = value.trim();
          continue;
        }
        payload[key] = value;
      }
    }

    final resp = await _client.patch(
      Uri.parse('$_baseUrl/auth/me'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Profil güncellenemedi: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addDeliveryProofPhoto(
    String deliveryId, {
    required String photoKey,
  }) async {
    final key = photoKey.trim();
    final resp = await _client.post(
      Uri.parse('$_baseUrl/deliveries/$deliveryId/proof'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{'photoKey': key}),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Kanit fotoğrafı eklenemedi: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> disputeDelivery(
    String deliveryId, {
    String? reason,
  }) async {
    final trimmed = reason?.trim();
    final resp = await _client.post(
      Uri.parse('$_baseUrl/deliveries/$deliveryId/dispute'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{
        if (trimmed != null) 'reason': trimmed,
      }),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Sorun bildirilemedi: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchUserById(String userId) async {
    final resp = await _client.get(
      Uri.parse('$_baseUrl/auth/users/$userId'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Kullanıcı bilgisi alınamadı: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // LOCAL PREFS (rol vb.)
  Future<String> getPreferredRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('preferred_role') ?? 'sender';
  }

  Future<void> setPreferredRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_role', role);
  }

  // LISTINGS
  Future<List<dynamic>> fetchListings({bool forceRefresh = false}) async {
    final now = DateTime.now();

    if (!forceRefresh) {
      final cached = _listingsCache;
      final cachedAt = _listingsCacheAt;
      if (cached != null && cachedAt != null && now.difference(cachedAt) <= _listingsMemoryTtl) {
        return cached;
      }

      // Warm-start: try disk cache once when memory cache is empty.
      if (cached == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final raw = prefs.getString(_listingsCacheKey);
          final atMillis = prefs.getInt(_listingsCacheAtKey);
          if (raw != null && atMillis != null) {
            final at = DateTime.fromMillisecondsSinceEpoch(atMillis);
            if (now.difference(at) <= _listingsDiskTtl) {
              final decoded = jsonDecode(raw);
              if (decoded is List<dynamic>) {
                _listingsCache = decoded;
                _listingsCacheAt = at;
                // Refresh in background; callers get instant stale cache.
                // ignore: unawaited_futures
                fetchListings(forceRefresh: true);
                return decoded;
              }
            }
          }
        } catch (_) {
          // Ignore cache errors.
        }
      }

      final inFlight = _listingsInFlight;
      if (inFlight != null) return inFlight;
    }

    final future = _fetchListingsFromNetwork();
    _listingsInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_listingsInFlight, future)) {
        _listingsInFlight = null;
      }
    }
  }

  Future<Map<String, dynamic>> fetchListingById(String listingId) async {
    final resp = await _client.get(
      Uri.parse('$_baseUrl/listings/$listingId'),
      headers: const <String, String>{
        'Content-Type': 'application/json',
      },
    );
    if (resp.statusCode >= 400) {
      throw Exception('İlan detayı alınamadı: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _fetchListingsFromNetwork() async {
    final resp = await _client.get(
      Uri.parse('$_baseUrl/listings'),
      headers: const <String, String>{
        'Content-Type': 'application/json',
      },
    );
    if (resp.statusCode >= 400) {
      throw Exception('İlanlar alınamadı: ${resp.body}');
    }
    final list = jsonDecode(resp.body) as List<dynamic>;
    _listingsCache = list;
    _listingsCacheAt = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_listingsCacheKey, jsonEncode(list));
      await prefs.setInt(_listingsCacheAtKey, _listingsCacheAt!.millisecondsSinceEpoch);
    } catch (_) {
      // Ignore disk cache failures.
    }
    if (kDebugMode) {
      // ignore: avoid_print
      print('ApiClient.fetchListings: status=${resp.statusCode} count=${list.length}');
    }
    return list;
  }

  Future<Map<String, dynamic>> createListing({
    required String title,
    required String description,
    required List<String> photos,
    required double weight,
    String? receiverPhone,
    double length = 0,
    double width = 0,
    double height = 0,
    bool fragile = false,
    double pickupLat = 0,
    double pickupLng = 0,
    double dropoffLat = 0,
    double dropoffLng = 0,
  }) async {
    await _getUserIdAndRole();

    final resp = await _client.post(
      Uri.parse('$_baseUrl/listings'),
      headers: _headers(),
      body: jsonEncode({
        'title': title,
        'description': description,
        'photos': photos,
        'weight': weight,
        'dimensions': {
          'length': length,
          'width': width,
          'height': height,
        },
        'fragile': fragile,
        'pickup_location': {'lat': pickupLat, 'lng': pickupLng},
        'dropoff_location': {'lat': dropoffLat, 'lng': dropoffLng},
        if (receiverPhone != null && receiverPhone.trim().isNotEmpty)
          'receiver_phone': receiverPhone.trim(),
      }),
    );
    if (resp.statusCode >= 400) {
      throw Exception('İlan oluşturulamadı: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> presignUpload({
    required String contentType,
    String prefix = 'uploads',
  }) async {
    await _getUserIdAndRole();

    final uri = Uri.parse('$_baseUrl/uploads/presign').replace(
      queryParameters: <String, String>{
        'contentType': contentType,
        'prefix': prefix,
      },
    );

    final resp = await _client.get(uri, headers: _headers());
    if (resp.statusCode >= 400) {
      throw Exception('Upload URL alınamadı: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<void> uploadToPresignedUrl({
    required String url,
    required Uint8List bytes,
    required Map<String, String> headers,
  }) async {
    final resp = await _client.put(
      Uri.parse(url),
      headers: headers,
      body: bytes,
    );

    // S3 PutObject commonly returns 200 or 204.
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('S3 upload başarısız: status=${resp.statusCode} body=${resp.body}');
    }
  }

  Future<Map<String, dynamic>> createOffer({
    required String listingId,
    required double amount,
    String? message,
  }) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/offers'),
      headers: _headers(),
      body: jsonEncode({
        'listingId': listingId,
        'amount': amount,
        if (message != null) 'message': message,
      }),
    );

    if (resp.statusCode >= 400) {
      throw Exception('Teklif oluşturulamadı: ${resp.body}');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchMyListings() async {
    final ownerId = await _getUserIdAndRole();
    final resp = await _client.get(
      Uri.parse('$_baseUrl/listings/owner/$ownerId'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Kendi ilanların alınamadı: ${resp.body}');
    }
    // Cache'e kaydet
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('my_listings_cache_$ownerId', jsonEncode(jsonDecode(resp.body)));
    } catch (_) {}
    return jsonDecode(resp.body) as List<dynamic>;
  }

  Future<List<dynamic>> fetchNearbyListings(double lat, double lng, {double radius = 50}) async {
    final resp = await _client.get(
      Uri.parse('$_baseUrl/listings/nearby?lat=$lat&lng=$lng&radius=$radius'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Yakındaki ilanlar alınamadı: ${resp.body}');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }
  
  Future<List<dynamic>> getMyListingsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ownerId = _userId; // _userId null olabilir, ama genelde set edilmiştir.
      // Eğer userId yoksa cache key de bulunamaz, o yüzden boş dön.
      // Ancak _getUserIdAndRole() denemek istersek o da network çağırabilir.
      // Basitlik için _userId varsa memoryden okuyalım.
      if (ownerId == null) return [];
      
      final raw = prefs.getString('my_listings_cache_$ownerId');
      if (raw != null) {
        return jsonDecode(raw) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  // OFFERS
  Future<List<dynamic>> fetchOffersForListing(String listingId) async {
    final resp = await _client.get(
      Uri.parse('$_baseUrl/offers/listing/$listingId'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Teklifler alınamadı: ${resp.body}');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> fetchOffersForListingPaged(
    String listingId, {
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/offers/listing/$listingId').replace(
      queryParameters: {
        'page': '${page < 1 ? 1 : page}',
        'limit': '${limit < 1 ? 20 : limit}',
      },
    );

    final resp = await _client.get(uri, headers: _headers());
    if (resp.statusCode >= 400) {
      throw Exception('Teklifler alınamadı: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List<dynamic>) {
      return {
        'data': decoded,
        'meta': {
          'total': decoded.length,
          'page': 1,
          'limit': decoded.length,
          'lastPage': 1,
        },
      };
    }
    throw Exception('Beklenmeyen offers response tipi');
  }

  Future<List<dynamic>> fetchOffersByOwner() async {
    final ownerId = await _getUserIdAndRole();
    final resp = await _client.get(
      Uri.parse('$_baseUrl/offers/owner/$ownerId'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Teklifler alınamadı: ${resp.body}');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> acceptOffer(String offerId) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/offers/accept/$offerId'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Teklif kabul edilemedi: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectOffer(String offerId) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/offers/reject/$offerId'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Teklif reddedilemedi: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // DELIVERIES
  Future<Map<String, dynamic>?> fetchDeliveryForListing(String listingId) async {
    final resp = await _client.get(
      Uri.parse('$_baseUrl/deliveries/by-listing/$listingId'),
      headers: _headers(),
    );
    if (resp.statusCode == 404) {
      return null;
    }
    if (resp.statusCode >= 400) {
      throw Exception('Teslimat bilgisi alınamadı: ${resp.body}');
    }
    final data = jsonDecode(resp.body);
    if (data == null) return null;
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchCarrierDeliveries() async {
    final carrierId = await _getUserIdAndRole();
    final resp = await _client.get(
      Uri.parse('$_baseUrl/deliveries/by-carrier/$carrierId'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Taşıyıcı teslimatları alınamadı: ${resp.body}');
    }
    // Cache'e kaydet
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sender_deliveries_cache_$carrierId', jsonEncode(jsonDecode(resp.body)));
    } catch (_) {}
    return jsonDecode(resp.body) as List<dynamic>;
  }

  // ADMIN
  Future<Map<String, dynamic>> fetchAdminStats() async {
    final resp = await _client.get(Uri.parse('$_baseUrl/admin/stats'), headers: _headers());
    if (resp.statusCode >= 400) throw Exception(resp.body);
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchAdminUsers({String? role, String? status, String? search, int page = 1}) async {
    var url = '$_baseUrl/admin/users?page=$page&limit=20';
    if (role != null) url += '&role=$role';
    if (status != null) url += '&status=$status';
    if (search != null && search.isNotEmpty) url += '&search=$search';

    final resp = await _client.get(Uri.parse(url), headers: _headers());
    if (resp.statusCode >= 400) throw Exception(resp.body);
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<void> adminVerifyUser(String userId, bool approve) async {
    final endpoint = approve ? 'verify' : 'reject';
    final resp = await _client.post(Uri.parse('$_baseUrl/admin/$endpoint/$userId'), headers: _headers());
    if (resp.statusCode >= 400) throw Exception(resp.body);
  }

  Future<void> adminSetBanStatus(String userId, bool ban) async {
    final endpoint = ban ? 'ban' : 'unban';
    final resp = await _client.post(Uri.parse('$_baseUrl/admin/$endpoint/$userId'), headers: _headers());
    if (resp.statusCode >= 400) throw Exception(resp.body);
  }


  Future<List<dynamic>> fetchSenderDeliveries() async {
    final ownerId = await _getUserIdAndRole();
    final resp = await _client.get(
      Uri.parse('$_baseUrl/deliveries/by-owner/$ownerId'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Teslimatlar alınamadı: ${resp.body}');
    }
    final list = jsonDecode(resp.body) as List<dynamic>;
    
    // Cache'e kaydet
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sender_deliveries_cache_$ownerId', jsonEncode(list));
    } catch (_) {}
    
    return list;
  }

  Future<List<dynamic>> getSenderDeliveriesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ownerId = _userId; 
      if (ownerId == null) return [];
      
      final raw = prefs.getString('sender_deliveries_cache_$ownerId');
      if (raw != null) {
        return jsonDecode(raw) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> pickupDelivery(String deliveryId) async {
    await _getUserIdAndRole();
    final resp = await _client.post(
      Uri.parse('$_baseUrl/deliveries/$deliveryId/pickup'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{}),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Teslimat alımı başarısız: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> pickupDeliveryWithQr(String deliveryId, {required String qrToken}) async {
    await _getUserIdAndRole();
    final resp = await _client.post(
      Uri.parse('$_baseUrl/deliveries/$deliveryId/pickup'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{'qrToken': qrToken}),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Teslimat alımı başarısız: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deliverDelivery(String deliveryId) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/deliveries/$deliveryId/deliver'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Teslim etme işlemi başarısız: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendDeliveryCode(String deliveryId) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/deliveries/$deliveryId/send-delivery-code'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Kod gönderme işlemi başarısız: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> confirmDeliveryWithFirebase(String deliveryId, {required String idToken}) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/deliveries/$deliveryId/confirm-delivery'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{'idToken': idToken}),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Teslim onayı başarısız: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchDeliveryById(String deliveryId) async {
    final resp = await _client.get(
      Uri.parse('$_baseUrl/deliveries/$deliveryId'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Teslimat bilgisi alınamadı: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateDeliveryLocation(String deliveryId, {required double lat, required double lng}) async {
    await _getUserIdAndRole();
    Future<http.Response> doPost() {
      return _client.post(
        Uri.parse('$_baseUrl/deliveries/$deliveryId/location'),
        headers: _headers(),
        body: jsonEncode(<String, dynamic>{'lat': lat, 'lng': lng}),
      );
    }

    var resp = await doPost();
    if (resp.statusCode == 401) {
      final refreshed = await refreshSession();
      if (refreshed) {
        resp = await doPost();
      }
    }
    if (resp.statusCode >= 400) {
      throw Exception('Konum güncelleme başarısız: ${resp.statusCode} - ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // RATINGS
  Future<Map<String, dynamic>> createRating({
    required String deliveryId,
    required int score,
    String? comment,
  }) async {
    await _getUserIdAndRole();

    final trimmed = comment?.trim();
    final resp = await _client.post(
      Uri.parse('$_baseUrl/ratings'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{
        'deliveryId': deliveryId,
        'score': score,
        if (trimmed != null && trimmed.isNotEmpty) 'comment': trimmed,
      }),
    );

    if (resp.statusCode == 409) {
      throw Exception('Bu teslimat için daha önce puan verdin.');
    }
    if (resp.statusCode >= 400) {
      throw Exception('Puan gönderilemedi: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<double> fetchAverageRating(String userId) async {
    final resp = await _client.get(
      Uri.parse('$_baseUrl/ratings/average/$userId'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Ortalama puan alınamadı: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final avg = data['average'];
    if (avg == null) return 0;
    if (avg is num) return avg.toDouble();
    return double.tryParse(avg.toString()) ?? 0;
  }

  Future<List<dynamic>> fetchUserRatings(String userId) async {
    final resp = await _client.get(
      Uri.parse('$_baseUrl/ratings/user/$userId'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Puanlar alınamadı: ${resp.body}');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  Future<List<dynamic>> fetchMyGivenRatings() async {
    await _getUserIdAndRole();
    final resp = await _client.get(
      Uri.parse('$_baseUrl/ratings/mine'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Verdiğin puanlar alınamadı: ${resp.body}');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  void followDeliveryUpdates(String deliveryId, void Function(dynamic) handler) {
    _ensureMessageSocket();
    _socket?.on('delivery_$deliveryId', handler);
  }

  void stopFollowingDelivery(String deliveryId) {
    _socket?.off('delivery_$deliveryId');
  }

  Future<String> getCurrentUserId() async {
    if (_userId != null) return _userId!;
    return await _getUserIdAndRole();
  }

  Future<List<Map<String, dynamic>>> fetchThreads() async {
    final resp = await _client.get(Uri.parse('$_baseUrl/messages'), headers: _headers());
    if (resp.statusCode >= 400) {
      throw Exception('Mesaj dizileri alınamadı: ${resp.body}');
    }
    return (jsonDecode(resp.body) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchMessages(String listingId) async {
    final resp = await _client.get(Uri.parse('$_baseUrl/messages/$listingId'), headers: _headers());
    if (resp.statusCode >= 400) {
      throw Exception('Mesajlar alınamadı: ${resp.body}');
    }
    return (jsonDecode(resp.body) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchContacts() async {
    final resp = await _client.get(Uri.parse('$_baseUrl/messages/contacts'), headers: _headers());
    if (resp.statusCode >= 400) {
      throw Exception('Kişi listesi alınamadı: ${resp.body}');
    }
    return (jsonDecode(resp.body) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> sendMessage({
    required String listingId,
    required String content,
    required String senderId,
    required String carrierId,
  }) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/messages'),
      headers: _headers(),
      body: jsonEncode({
        'listingId': listingId,
        'content': content,
        'senderId': senderId,
        'carrierId': carrierId,
      }),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Mesaj gönderilemedi: ${resp.statusCode} ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  void followListingMessages(String listingId, void Function(dynamic) handler) {
    _ensureMessageSocket();
    _socket?.on('message_$listingId', handler);
  }

  void stopFollowingListing(String listingId) {
    _socket?.off('message_$listingId');
  }

  void followOfferUpdates(String listingId, void Function(dynamic) handler) {
    _ensureMessageSocket();
    _socket?.on('offer_$listingId', handler);
  }

  void stopFollowingOfferUpdates(String listingId) {
    _socket?.off('offer_$listingId');
  }

  void addSocketStatusListener(void Function(bool) listener) {
    _socketStatusListeners.add(listener);
  }

  void removeSocketStatusListener(void Function(bool) listener) {
    _socketStatusListeners.remove(listener);
  }

  void _notifySocketStatus(bool connected) {
    for (final l in List.of(_socketStatusListeners)) {
      l(connected);
    }
  }

  bool get isSocketConnected => _socket?.connected == true;

  void _ensureMessageSocket() {
    if (_socket != null && _socket!.connected) return;
    _socket = IO.io('https://kargo-backend-production.up.railway.app', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {'Authorization': 'Bearer ${_jwt ?? ''}'},
      'forceNew': true,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
    });

    _socket?.on('connect', (_) {
      _log('✅ Socket connected successfully');
      _notifySocketStatus(true);
    });

    _socket?.on('disconnect', (_) {
      _log('❌ Socket disconnected');
      _notifySocketStatus(false);
    });

    _socket?.on('connect_error', (error) {
      _log('❌ Socket connection error: $error');
      _notifySocketStatus(false);
    });

    _socket?.on('reconnect', (_) {
      _log('🔄 Socket reconnected');
      _notifySocketStatus(true);
    });

    _socket?.connect();

    // Test connection after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (_socket?.connected == true) {
      } else {
        if (kDebugMode) {
          // ignore: avoid_print
          print('❌ Socket failed to connect');
        }
      }
    });
  }
}

final apiClient = ApiClient();


