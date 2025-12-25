import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/delivery_status.dart';
import '../../../theme/bitasi_theme.dart';

class CarrierDeliveryCard extends StatelessWidget {
  const CarrierDeliveryCard({
    super.key,
    required this.item,
    required this.onOpenDetails,
    required this.onOpenLiveTracking,
    required this.onPickup,
    required this.onSendCode,
  });

  final Map<String, dynamic> item;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenLiveTracking;
  final VoidCallback onPickup;
  final VoidCallback onSendCode;

  @override
  Widget build(BuildContext context) {
    final id = item['id']?.toString() ?? '';
    final listingId = item['listingId']?.toString() ?? '';
    final listing = (item['listing'] as Map?)?.map((k, v) => MapEntry(k.toString(), v));
    final title = listing?['title']?.toString().trim();
    final status = item['status']?.toString().toLowerCase() ?? '';
    final receiverPhone = item['receiver_phone']?.toString() ?? '';
    final pickupAt = item['pickupAt']?.toString() ?? '';
    final deliveredAt = item['deliveredAt']?.toString() ?? '';

    final pickupAtLabel = _formatDateTimeOrRaw(pickupAt);
    final deliveredAtLabel = _formatDateTimeOrRaw(deliveredAt);

    final resolvedListingId = (listing?['id']?.toString() ?? listingId).trim();
    final resolvedTitle = (title ?? '').trim();
    final cardTitle = resolvedTitle.isNotEmpty
        ? resolvedTitle
        : (resolvedListingId.isNotEmpty
            ? 'İlan #${_shortId(resolvedListingId)}'
            : (id.isNotEmpty ? 'Teslimat #${_shortId(id)}' : 'Teslimat'));

    final subtitle = receiverPhone.trim().isNotEmpty
        ? 'Alıcı: $receiverPhone'
        : (resolvedListingId.isNotEmpty ? 'İlan: ${_shortId(resolvedListingId)}' : '');

    final ui = _statusUi(status);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onOpenDetails,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: BiTasiColors.backgroundGrey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_shipping, color: BiTasiColors.primaryRed),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ui.color.withAlpha(26),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      ui.label,
                      style: TextStyle(
                        color: ui.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (receiverPhone.trim().isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Alıcı: $receiverPhone',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (pickupAtLabel.isNotEmpty || deliveredAtLabel.isNotEmpty) ...[
                if (receiverPhone.trim().isNotEmpty) const SizedBox(height: 6),
                if (pickupAtLabel.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.qr_code_2, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Alındı: $pickupAtLabel',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (deliveredAtLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Teslim: $deliveredAtLabel',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              if (status == DeliveryStatus.pickupPending ||
                  status == DeliveryStatus.inTransit ||
                  status == DeliveryStatus.atDoor ||
                  status == DeliveryStatus.delivered) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (status == DeliveryStatus.pickupPending)
                      FilledButton(
                        onPressed: id.isEmpty ? null : onPickup,
                        style: FilledButton.styleFrom(
                          backgroundColor: BiTasiColors.primaryRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: const Text('Teslimatı Al'),
                      ),
                    if (status == DeliveryStatus.inTransit || status == DeliveryStatus.atDoor) ...[
                      OutlinedButton.icon(
                        onPressed: id.isEmpty ? null : onOpenLiveTracking,
                        icon: const Icon(Icons.location_searching, size: 18),
                        label: const Text('Takip'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: id.isEmpty ? null : onSendCode,
                        icon: const Icon(Icons.sms_outlined, size: 18),
                        label: const Text('Kod Gönder'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusUi {
  const _StatusUi({required this.label, required this.color});

  final String label;
  final Color color;
}

_StatusUi _statusUi(String status) {
  if (status == DeliveryStatus.pickupPending) {
    return const _StatusUi(label: 'Alım bekleniyor', color: BiTasiColors.warningOrange);
  }
  if (status == DeliveryStatus.inTransit) {
    return const _StatusUi(label: 'Yolda', color: BiTasiColors.primaryRed);
  }
  if (status == DeliveryStatus.atDoor) {
    return const _StatusUi(label: 'Kapıda', color: BiTasiColors.warningOrange);
  }
  if (status == DeliveryStatus.delivered) {
    return const _StatusUi(label: 'Teslim edildi', color: BiTasiColors.successGreen);
  }
  if (status == DeliveryStatus.cancelled) {
    return const _StatusUi(label: 'İptal', color: Colors.grey);
  }
  if (status == DeliveryStatus.disputed) {
    return const _StatusUi(label: 'Uyuşmazlık', color: BiTasiColors.errorRed);
  }
  return const _StatusUi(label: 'Bilinmiyor', color: Colors.grey);
}

String _formatDateTimeOrRaw(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  return DateFormat('dd.MM.yyyy HH:mm').format(local);
}

String _shortId(String value, {int len = 6}) {
  final v = value.trim();
  if (v.isEmpty) return '';
  return v.length <= len ? v : v.substring(0, len);
}
