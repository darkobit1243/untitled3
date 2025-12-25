import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> showPickupQrDialog(BuildContext context, String token) {
  return showDialog<void>(
    context: context,
    builder: (_) => PickupQrDialog(token: token),
  );
}

class PickupQrDialog extends StatelessWidget {
  const PickupQrDialog({
    super.key,
    required this.token,
  });

  final String token;

  @override
  Widget build(BuildContext context) {
    // NOTE: AlertDialog uses IntrinsicWidth/IntrinsicHeight which can trigger
    // intrinsic measurement on children. qr_flutter internally uses LayoutBuilder,
    // which throws during intrinsic sizing. A sized Dialog avoids that path.
    final painter = QrPainter(
      data: token,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Teslimat QR Kodu',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: 220,
                height: 220,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CustomPaint(
                  painter: painter,
                  size: const Size.square(200),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Kurye teslimatı almak için bu QR kodu okutmalıdır.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kapat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
