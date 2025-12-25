import 'package:flutter/material.dart';

import '../../theme/bitasi_theme.dart';
import 'status_chip.dart';

class MyShipmentsListingCard extends StatelessWidget {
  const MyShipmentsListingCard({
    super.key,
    required this.listing,
    required this.hasOfferBadge,
    required this.onOpenOffers,
  });

  final Map<String, dynamic> listing;
  final bool hasOfferBadge;
  final void Function(String listingId, String title) onOpenOffers;

  @override
  Widget build(BuildContext context) {
    final listingId = listing['id']?.toString() ?? '';
    final pickup = listing['pickup_location']?['address']?.toString() ?? '–';
    final dropoff = listing['dropoff_location']?['address']?.toString() ?? '–';
    final title = listing['title']?.toString() ?? 'Gönderi ${listing['id'] ?? ''}';
    const status = 'active';
    final weight = listing['weight']?.toString() ?? '-';

    return Card(
      color: Colors.white.withAlpha(242),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                if (hasOfferBadge)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: BiTasiColors.primaryRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                const MyShipmentsStatusChip(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Text('Kalkış: $pickup • Varış: $dropoff', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text('Ağırlık: $weight kg', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => onOpenOffers(listingId, title),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BiTasiColors.primaryBlue,
                  ),
                  child: const Text('Teklifleri Gör'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
