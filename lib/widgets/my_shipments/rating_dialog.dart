import 'package:flutter/material.dart';

import '../../theme/bitasi_theme.dart';

Future<void> showRatingDialog({
  required BuildContext context,
  required String title,
  required Future<void> Function(int score) onSubmit,
  VoidCallback? onSuccess,
}) {
  int score = 5;
  bool submitting = false;
  String? error;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            if (submitting) return;
            setDialogState(() {
              submitting = true;
              error = null;
            });
            try {
              await onSubmit(score);
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              onSuccess?.call();
            } catch (e) {
              setDialogState(() {
                error = e.toString();
              });
            } finally {
              setDialogState(() {
                submitting = false;
              });
            }
          }

          Widget star(int i) {
            final selected = i <= score;
            return IconButton(
              onPressed: submitting
                  ? null
                  : () {
                      setDialogState(() {
                        score = i;
                      });
                    },
              icon: Icon(
                selected ? Icons.star : Icons.star_border,
                color: BiTasiColors.warningOrange,
              ),
            );
          }

          return AlertDialog(
            title: Text('Puan Ver: $title'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Taşıyıcıyı değerlendir', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [star(1), star(2), star(3), star(4), star(5)],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: submitting ? null : submit,
                style: ElevatedButton.styleFrom(backgroundColor: BiTasiColors.primaryRed),
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Gönder'),
              ),
            ],
          );
        },
      );
    },
  );
}
