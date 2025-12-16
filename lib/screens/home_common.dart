import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const String kCargoPinAssetPath = 'assets/markers/cargo_pin.png';

Future<BitmapDescriptor> createCargoPinMarkerBitmapDescriptor({
  int size = 86,
  Color fallbackColor = const Color(0xFFFF9800),
}) async {
  try {
    // Ensure the asset exists; BitmapDescriptor.asset may fail silently on some platforms
    // when the asset path is wrong.
    await rootBundle.load(kCargoPinAssetPath);
    return BitmapDescriptor.asset(
      ImageConfiguration(size: Size(size.toDouble(), size.toDouble())),
      kCargoPinAssetPath,
    );
  } catch (_) {
    return createCargoBoxMarkerBitmapDescriptor(fallbackColor, size: size);
  }
}

Future<BitmapDescriptor> createMarkerBitmapDescriptor(Color color, {int size = 96}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));

  final center = Offset(size / 2, size / 2 - 8);

  final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.25);
  canvas.drawCircle(center.translate(0, 3), size * 0.38, shadowPaint);

  final borderPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
  canvas.drawCircle(center, size * 0.34, borderPaint);

  final fillPaint = Paint()..color = color..style = PaintingStyle.fill;
  canvas.drawCircle(center, size * 0.28, fillPaint);

  final tailBorder = Path()
    ..moveTo(size / 2 - 12, center.dy + (size * 0.28))
    ..quadraticBezierTo(size / 2, size - 10, size / 2 + 12, center.dy + (size * 0.28))
    ..close();
  canvas.drawPath(tailBorder, borderPaint);

  final tailInner = Path()
    ..moveTo(size / 2 - 8, center.dy + (size * 0.28) - 2)
    ..quadraticBezierTo(size / 2, size - 12, size / 2 + 8, center.dy + (size * 0.28) - 2)
    ..close();
  canvas.drawPath(tailInner, fillPaint);

  final picture = recorder.endRecording();
  final img = await picture.toImage(size, size);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();
  return BitmapDescriptor.bytes(bytes);
}

Future<BitmapDescriptor> createSmallLocationMarkerBitmapDescriptor({Color color = Colors.blueGrey, int size = 44}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));

  final center = Offset(size / 2, size / 2);

  final shadow = Paint()..color = Colors.black.withValues(alpha: 0.20);
  canvas.drawCircle(center.translate(0, 2), size * 0.30, shadow);

  final border = Paint()..color = Colors.white..style = PaintingStyle.fill;
  canvas.drawCircle(center, size * 0.28, border);

  final fill = Paint()..color = color..style = PaintingStyle.fill;
  canvas.drawCircle(center, size * 0.22, fill);

  final picture = recorder.endRecording();
  final img = await picture.toImage(size, size);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();
  return BitmapDescriptor.bytes(bytes);
}

Future<BitmapDescriptor> createCargoBoxMarkerBitmapDescriptor(Color color, {int size = 86}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));

  final center = Offset(size / 2, size / 2 - 10);

  // Base pin (same silhouette as the existing marker)
  final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.25);
  canvas.drawCircle(center.translate(0, 3), size * 0.38, shadowPaint);

  final borderPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
  canvas.drawCircle(center, size * 0.34, borderPaint);

  final fillPaint = Paint()..color = color..style = PaintingStyle.fill;
  canvas.drawCircle(center, size * 0.28, fillPaint);

  final tailBorder = Path()
    ..moveTo(size / 2 - 14, center.dy + (size * 0.28))
    ..quadraticBezierTo(size / 2, size - 10, size / 2 + 14, center.dy + (size * 0.28))
    ..close();
  canvas.drawPath(tailBorder, borderPaint);

  final tailInner = Path()
    ..moveTo(size / 2 - 10, center.dy + (size * 0.28) - 2)
    ..quadraticBezierTo(size / 2, size - 12, size / 2 + 10, center.dy + (size * 0.28) - 2)
    ..close();
  canvas.drawPath(tailInner, fillPaint);

  // Cargo box icon (white) on top of fill circle
  final iconPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = (size * 0.04).clamp(2.0, 5.0)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final w = size * 0.22;
  final h = size * 0.18;
  final rect = Rect.fromCenter(center: center.translate(0, 2), width: w, height: h);
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size * 0.02));
  canvas.drawRRect(rrect, iconPaint);

  // Top flap line
  final flapY = rect.top + h * 0.38;
  canvas.drawLine(Offset(rect.left, flapY), Offset(rect.right, flapY), iconPaint);

  // Middle seam
  canvas.drawLine(Offset(center.dx, flapY), Offset(center.dx, rect.bottom), iconPaint);

  final picture = recorder.endRecording();
  final img = await picture.toImage(size, size);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();
  return BitmapDescriptor.bytes(bytes);
}

List<LatLng> decodePolyline(String encoded) {
  final List<LatLng> points = [];
  int index = 0;
  int lat = 0;
  int lng = 0;

  while (index < encoded.length) {
    int b;
    int shift = 0;
    int result = 0;

    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);

    final int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;

    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);

    final int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    final double latitude = lat / 1e5;
    final double longitude = lng / 1e5;
    points.add(LatLng(latitude, longitude));
  }

  return points;
}
