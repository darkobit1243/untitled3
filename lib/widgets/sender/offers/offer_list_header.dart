import 'package:flutter/material.dart';

import '../../../theme/bitasi_theme.dart';

class OfferListHeader extends StatelessWidget {
  const OfferListHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.countLabel,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final String countLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: BiTasiColors.primaryBlue.withAlpha(16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                countLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: BiTasiColors.primaryBlue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ],
        ),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
