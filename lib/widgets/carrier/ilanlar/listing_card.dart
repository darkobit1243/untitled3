import 'package:flutter/material.dart';

import '../../../theme/bitasi_theme.dart';
import '../../../utils/carrier/image_utils.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.item,
    required this.onDetailPressed,
    required this.onOfferPressed,
    required this.onProfilePressed,
  });

  final Map<String, dynamic> item;
  final VoidCallback onDetailPressed;
  final VoidCallback onOfferPressed;
  final VoidCallback onProfilePressed;

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? 'İlan';
    final pickup = item['pickup_location']?['display']?.toString() ??
        item['pickup_location']?['address']?.toString() ??
        'Kalkış';
    final dropoff = item['dropoff_location']?['display']?.toString() ??
        item['dropoff_location']?['address']?.toString() ??
        'Varış';
    final price = item['price']?.toString() ?? '—';
    final weight = item['weight']?.toString() ?? '-';
    final distance = (item['__distance'] as num?)?.toStringAsFixed(1) ?? '–';

    final ownerName = item['ownerName']?.toString() ?? 'Gönderici';
    final ownerAvatar = item['ownerAvatar']?.toString();
    final ownerAvatarProvider = ImageUtils.imageProviderFromString(ownerAvatar);
    final rating = (item['ownerRating'] as num?)?.toDouble();
    final delivered = (item['ownerDelivered'] as num?)?.toInt();
    final ownerInitial = ownerName.isNotEmpty ? ownerName.characters.first.toUpperCase() : 'G';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.black.withAlpha(13),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                _pill('$weight kg'),
                const SizedBox(width: 8),
                _chip(distance == '–' ? 'Mesafe yok' : '$distance km'),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: onProfilePressed,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: ownerAvatarProvider,
                    child: ownerAvatarProvider == null
                        ? Text(ownerInitial, style: const TextStyle(fontWeight: FontWeight.w700))
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ownerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        Row(
                          children: [
                            if (rating != null) ...[
                              const Icon(Icons.star, size: 12, color: Colors.amber),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                            if (delivered != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '$delivered teslimat',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.person_outline, size: 18, color: Colors.black54),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _locationRow(icon: Icons.my_location, text: pickup),
            _locationRow(icon: Icons.place, text: dropoff),
            const SizedBox(height: 10),
            Text(
              price,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: onDetailPressed,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.info_outline, size: 16, color: Colors.black54),
                  label: const Text('Detay', style: TextStyle(color: Colors.black87, fontSize: 12)),
                ),
                ElevatedButton(
                  onPressed: onOfferPressed,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    backgroundColor: BiTasiColors.primaryRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  child: const Text('Teklif Ver'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
