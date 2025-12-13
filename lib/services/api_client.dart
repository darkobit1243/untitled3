import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Basit kargo-backend HTTP istemcisi.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  bool enableLogging = false;

  /// Production backend base URL (Railway).
  ///
  /// Tüm platformlarda aynı URL'yi kullanıyoruz.
  String get _baseUrl => 'https://kargo-backend-production.up.railway.app';

  String? _jwt;
  String? _userId;
  IO.Socket? _socket;
  final List<void Function(bool)> _socketStatusListeners = [];

  void _log(String message) {
    if (enableLogging) {
      // ignore: avoid_print
      print(message);
    }
  }

  void setToken(String token) {
    _jwt = token;
    _persistToken(token);
  }

  Future<void> _persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('preferred_role');
  }

  Future<void> clearToken() async {
    _jwt = null;
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('preferred_role');
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
    final r = (data['role'] as String?) ?? role;
    setToken(token);
    await setPreferredRole(r);
  }

  Future<String> login(String email, String password) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );

    // Debug için response'u logla (sadece geliştirme sırasında işine yarar)
    // ignore: avoid_print
    print('LOGIN RESPONSE: ${resp.statusCode} ${resp.body}');

    if (resp.statusCode >= 400) {
      throw Exception('Giriş başarısız: ${resp.statusCode} - ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = data['token'] as String;
    final r = data['role'] as String?; // sender|carrier
    setToken(token);
    if (r != null) {
      await setPreferredRole(r);
    }
    return token;
  }

  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return false;
    _jwt = token;
    try {
      await _getUserIdAndRole();
      return true;
    } catch (_) {
      await clearToken();
      return false;
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
    final id = idValue as String;
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
  Future<List<dynamic>> fetchListings() async {
    final resp = await _client.get(
      Uri.parse('$_baseUrl/listings'),
      headers: _headers(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('İlanlar alınamadı: ${resp.body}');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createListing({
    required String title,
    required String description,
    required double weight,
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
        'photos': <String>[],
        'weight': weight,
        'dimensions': {
          'length': length,
          'width': width,
          'height': height,
        },
        'fragile': fragile,
        'pickup_location': {'lat': pickupLat, 'lng': pickupLng},
        'dropoff_location': {'lat': dropoffLat, 'lng': dropoffLng},
      }),
    );
    if (resp.statusCode >= 400) {
      throw Exception('İlan oluşturulamadı: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
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
    return jsonDecode(resp.body) as List<dynamic>;
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
      throw Exception('Teslimatlar alınamadı: ${resp.body}');
    }
    return jsonDecode(resp.body) as List<dynamic>;
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
    return jsonDecode(resp.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> pickupDelivery(String deliveryId) async {
    await _getUserIdAndRole();
    final resp = await _client.post(
      Uri.parse('$_baseUrl/deliveries/$deliveryId/pickup'),
      headers: _headers(),
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
    required bool fromCarrier,
  }) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/messages'),
      headers: _headers(),
      body: jsonEncode({
        'listingId': listingId,
        'content': content,
        'senderId': senderId,
        'carrierId': carrierId,
        'fromCarrier': fromCarrier,
      }),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Mesaj gönderilemedi: ${resp.body}');
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
        print('✅ Socket is connected and ready');
      } else {
        print('❌ Socket failed to connect');
      }
    });
  }
}

final apiClient = ApiClient();


