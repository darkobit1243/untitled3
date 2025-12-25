import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ImageUtils {
  const ImageUtils._();

  static List<String> photosFromListing(Map<String, dynamic> item) {
    final urls = <String>[];

    final photos = item['photos'];
    if (photos is List) {
      for (final p in photos) {
        if (p is String && p.trim().isNotEmpty) {
          urls.add(p.trim());
        }
      }
    }

    if (urls.isEmpty) {
      for (final key in const ['photo', 'photoUrl', 'image', 'imageUrl']) {
        final v = item[key];
        if (v is String && v.trim().isNotEmpty) {
          urls.add(v.trim());
          break;
        }
      }
    }

    return urls;
  }

  static bool isHttpUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
  }

  static bool isBase64ImageDataUrl(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('data:image/') && trimmed.contains('base64,');
  }

  static Uint8List? tryDecodeBase64ImageDataUrl(String value) {
    try {
      final trimmed = value.trim();
      final idx = trimmed.indexOf('base64,');
      if (idx < 0) return null;
      final b64 = trimmed.substring(idx + 'base64,'.length);
      if (b64.isEmpty) return null;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  static ImageProvider? imageProviderFromString(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (isBase64ImageDataUrl(trimmed)) {
      final bytes = tryDecodeBase64ImageDataUrl(trimmed);
      if (bytes == null) return null;
      return MemoryImage(bytes);
    }
    if (isHttpUrl(trimmed)) {
      return NetworkImage(trimmed);
    }
    return null;
  }

  static Widget imageWidgetFromString(
    String value, {
    BoxFit fit = BoxFit.cover,
    Widget? errorWidget,
    Widget? loadingWidget,
  }) {
    final trimmed = value.trim();

    final fallback = errorWidget ??
        Container(
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.black45),
        );

    if (isBase64ImageDataUrl(trimmed)) {
      final bytes = tryDecodeBase64ImageDataUrl(trimmed);
      if (bytes == null) return fallback;
      return Image.memory(bytes, fit: fit, errorBuilder: (_, __, ___) => fallback);
    }

    if (isHttpUrl(trimmed)) {
      final defaultLoading = Container(
        color: Colors.black.withAlpha(30),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );

      return Image.network(
        trimmed,
        fit: fit,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return loadingWidget ?? defaultLoading;
        },
      );
    }

    return fallback;
  }
}
