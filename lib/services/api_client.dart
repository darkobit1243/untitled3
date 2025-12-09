import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

/// Basit kargo-backend HTTP istemcisi.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Ortama göre backend base URL'si.
  ///
  /// - Android emülatör: 10.0.2.2
  /// - iOS simülatör / web: localhost
  /// - Fiziksel cihazda çalıştırıyorsan: bunu makinenin yerel IP'siyle
  ///   (ör: http://192.168.1.42:3000) değiştirmelisin.
  String get _baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  String? _jwt;

  void setToken(String token) {
    _jwt = token;
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
  Future<void> register(String email, String password) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Kayıt başarısız: ${resp.body}');
    }
  }

  Future<String> login(String email, String password) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Giriş başarısız: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = data['token'] as String;
    setToken(token);
    return token;
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
}


