import 'package:flutter/material.dart';

class RoleSummaryCard extends StatelessWidget {
  const RoleSummaryCard({
    super.key,
    required this.role,
    required this.isLoading,
    this.error,
    this.senderListingCount,
    this.senderPendingOffers,
    this.carrierDeliveryCount,
  });

  final String role;
  final bool isLoading;
  final String? error;
  final int? senderListingCount;
  final int? senderPendingOffers;
  final int? carrierDeliveryCount;

  @override
  Widget build(BuildContext context) {
    final isSender = role == 'sender';
    final title = isSender ? 'Gönderici Paneli' : 'Taşıyıcı Paneli';
    String subtitle;
    if (isLoading) {
      subtitle = 'Yükleniyor...';
    } else if (error != null) {
      subtitle = error!;
    } else if (isSender) {
      final offersTxt = senderPendingOffers != null ? ' • $senderPendingOffers bekleyen teklif' : '';
      subtitle = '${senderListingCount ?? 0} ilan$offersTxt';
    } else {
      subtitle = '${carrierDeliveryCount ?? 0} teslimat';
    }

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
            const Spacer(),
            Icon(isSender ? Icons.local_shipping : Icons.route, color: Colors.black54, size: 20),
          ],
        ),
      ),
    );
  }
}
