import 'package:flutter/material.dart';

import '../../../theme/bitasi_theme.dart';

class OfferEmptyState extends StatelessWidget {
  const OfferEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: BiTasiColors.primaryBlue.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_offer_outlined,
                color: BiTasiColors.primaryBlue,
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Hiç teklifin yok',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Bu ilana teklif gelince burada listelenecek.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
