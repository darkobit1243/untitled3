import 'package:flutter/material.dart';

import '../../../theme/bitasi_theme.dart';

class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.amountLabel,
    required this.status,
    required this.userLabel,
    required this.avatarUrl,
    required this.rating,
    required this.delivered,
    required this.createdAtLabel,
    required this.actionLoading,
    required this.onReject,
    required this.onAccept,
    required this.onViewProfile,
  });

  final String amountLabel;
  final String status;
  final String userLabel;
  final String? avatarUrl;
  final double? rating;
  final int? delivered;
  final String createdAtLabel;
  final bool actionLoading;
  final VoidCallback? onReject;
  final VoidCallback? onAccept;
  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    switch (status) {
      case 'accepted':
        statusColor = BiTasiColors.successGreen;
        statusText = 'Kabul edildi';
        break;
      case 'rejected':
        statusColor = BiTasiColors.errorRed;
        statusText = 'Reddedildi';
        break;
      default:
        statusColor = BiTasiColors.warningOrange;
        statusText = 'Bekliyor';
    }

    final isPending = status == 'pending';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withAlpha(35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: BiTasiColors.primaryBlue.withAlpha(31),
                  backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: (avatarUrl == null || avatarUrl!.isEmpty)
                      ? const Icon(Icons.local_shipping, color: BiTasiColors.primaryBlue)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        amountLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(31),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (rating != null) ...[
                  const Icon(Icons.star, size: 12, color: Colors.amber),
                  Text(
                    rating!.toStringAsFixed(1),
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
                const Spacer(),
                if (onViewProfile != null)
                  TextButton(
                    onPressed: onViewProfile,
                    child: const Text('Profili Gör'),
                  ),
              ],
            ),
            if (createdAtLabel.isNotEmpty)
              Text(
                createdAtLabel,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: actionLoading ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BiTasiColors.errorRed,
                        side: const BorderSide(color: BiTasiColors.errorRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reddet'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: actionLoading ? null : onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BiTasiColors.successGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Kabul Et'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
