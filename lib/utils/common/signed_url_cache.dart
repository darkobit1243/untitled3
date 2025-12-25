class SignedUrlCache {
  SignedUrlCache({this.ttl = const Duration(minutes: 8)});

  final Duration ttl;
  final Map<String, _SignedUrlEntry> _cache = <String, _SignedUrlEntry>{};

  String? resolve({required String? key, required String? signedUrl}) {
    final url = signedUrl?.trim();
    if (url == null || url.isEmpty) return null;

    final k = key?.trim();
    if (k == null || k.isEmpty) return url;

    final now = DateTime.now();
    final existing = _cache[k];
    if (existing != null && existing.expiresAt.isAfter(now)) {
      return existing.url;
    }

    _cache[k] = _SignedUrlEntry(url: url, expiresAt: now.add(ttl));
    return url;
  }

  void prune() {
    final now = DateTime.now();
    _cache.removeWhere((_, v) => !v.expiresAt.isAfter(now));
  }
}

class _SignedUrlEntry {
  final String url;
  final DateTime expiresAt;

  const _SignedUrlEntry({required this.url, required this.expiresAt});
}

final SignedUrlCache signedUrlCache = SignedUrlCache();
