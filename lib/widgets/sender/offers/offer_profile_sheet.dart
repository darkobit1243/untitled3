import 'package:flutter/material.dart';

import '../../../theme/bitasi_theme.dart';

class OfferProfileSheet extends StatelessWidget {
  const OfferProfileSheet({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.role,
    required this.rating,
    required this.delivered,
    required this.isVerified,
    required this.isActive,
    required this.phone,
    required this.address,
  });

  final String? avatarUrl;
  final String name;
  final String? role;
  final double? rating;
  final int? delivered;
  final bool isVerified;
  final bool isActive;
  final String? phone;
  final String? address;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 46,
              height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Profil',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: (avatarUrl == null || avatarUrl!.isEmpty)
                    ? Text(
                        (name.isNotEmpty) ? name.characters.first.toUpperCase() : 'U',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    if (role != null && role!.isNotEmpty)
                      Text(
                        role == 'carrier'
                            ? 'Taşıyıcı'
                            : (role == 'sender' ? 'Gönderici' : role!),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isVerified
                                    ? BiTasiColors.successGreen
                                    : BiTasiColors.warningOrange)
                                .withAlpha(22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVerified
                                    ? Icons.verified_rounded
                                    : Icons.hourglass_top_rounded,
                                size: 14,
                                color: isVerified
                                    ? BiTasiColors.successGreen
                                    : BiTasiColors.warningOrange,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isVerified ? 'Doğrulandı' : 'Doğrulanmadı',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isVerified
                                      ? BiTasiColors.successGreen
                                      : BiTasiColors.warningOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isActive
                                    ? BiTasiColors.primaryBlue
                                    : BiTasiColors.errorRed)
                                .withAlpha(18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isActive ? 'Aktif' : 'Pasif',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isActive
                                  ? BiTasiColors.primaryBlue
                                  : BiTasiColors.errorRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.withAlpha(35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        rating != null ? rating!.toStringAsFixed(1) : '-',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'puan',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.withAlpha(35)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_shipping_outlined,
                          size: 18, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        delivered != null ? '$delivered' : '-',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'teslimat',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if ((phone?.trim().isNotEmpty ?? false))
            Row(
              children: [
                Icon(Icons.phone_rounded, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    phone!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          if ((address?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address!,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
