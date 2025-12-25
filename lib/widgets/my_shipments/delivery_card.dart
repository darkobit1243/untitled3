import 'package:flutter/material.dart';

import '../../models/delivery_status.dart';
import '../../theme/bitasi_theme.dart';
import 'simple_timeline.dart';
import 'status_chip.dart';

class MyShipmentsDeliveryCard extends StatelessWidget {
  const MyShipmentsDeliveryCard({
    super.key,
    required this.delivery,
    required this.isRated,
    required this.onShowPickupQr,
    required this.onOpenLiveTracking,
    required this.onRate,
    required this.onOpenDetails,
  });

  final Map<String, dynamic> delivery;
  final bool isRated;
  final void Function(String pickupQrToken) onShowPickupQr;
  final void Function(String deliveryId) onOpenLiveTracking;
  final void Function(String deliveryId, String title) onRate;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final listing = (delivery['listing'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final carrier = delivery['carrier'] as Map<String, dynamic>?;
    final acceptedOffer = delivery['acceptedOffer'] as Map<String, dynamic>?;

    final deliveryId = delivery['id']?.toString() ?? '';
    final pickupQrToken = delivery['pickupQrToken']?.toString() ?? '';
    final pickup = listing['pickup_location']?['address']?.toString() ?? '–';
    final dropoff = listing['dropoff_location']?['address']?.toString() ?? '–';
    final title = listing['title']?.toString() ?? 'İlan ${delivery['listingId'] ?? delivery['id'] ?? ''}';
    final status = delivery['status']?.toString().toLowerCase() ?? 'unknown';
    final trackingEnabled = delivery['trackingEnabled'] == true;
    final amount = listing['weight']?.toString() ?? '-';

    final carrierFullName = carrier?['fullName']?.toString().trim();
    final carrierEmail = carrier?['email']?.toString().trim();
    final carrierName = (carrierFullName != null && carrierFullName.isNotEmpty)
        ? carrierFullName
        : ((carrierEmail != null && carrierEmail.isNotEmpty) ? carrierEmail : null);

    final acceptedAmount = (acceptedOffer?['amount'] as num?)?.toDouble();

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
                MyShipmentsStatusChip(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Text('Kalkış: $pickup • Varış: $dropoff', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text('Ağırlık: $amount kg', style: const TextStyle(fontWeight: FontWeight.w600)),
            if ((carrierName ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Taşıyıcı: $carrierName', style: const TextStyle(color: Colors.black87)),
            ],
            if (acceptedAmount != null && acceptedAmount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Ücret: ${acceptedAmount.toStringAsFixed(0)} TL',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            MyShipmentsSimpleTimeline(status: status),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (status == DeliveryStatus.pickupPending && pickupQrToken.isNotEmpty)
                  ElevatedButton(
                    onPressed: () => onShowPickupQr(pickupQrToken),
                    style: ElevatedButton.styleFrom(backgroundColor: BiTasiColors.primaryBlue),
                    child: const Text('QR Göster'),
                  ),
                if (trackingEnabled && deliveryId.isNotEmpty)
                  ElevatedButton(
                    onPressed: () => onOpenLiveTracking(deliveryId),
                    style: ElevatedButton.styleFrom(backgroundColor: BiTasiColors.primaryRed),
                    child: const Text('Canlı Takip'),
                  ),
                if (status == DeliveryStatus.delivered && deliveryId.isNotEmpty)
                  ElevatedButton(
                    onPressed: isRated ? null : () => onRate(deliveryId, title),
                    style: ElevatedButton.styleFrom(backgroundColor: BiTasiColors.successGreen),
                    child: Text(isRated ? 'Puanlandı' : 'Puan Ver'),
                  ),
                ElevatedButton(
                  onPressed: onOpenDetails,
                  style: ElevatedButton.styleFrom(backgroundColor: BiTasiColors.backgroundGrey),
                  child: const Text('Gönderi Detayı'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
