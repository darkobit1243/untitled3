import 'package:flutter/material.dart';

import '../../theme/bitasi_theme.dart';

class MyShipmentsStatusChip extends StatelessWidget {
  const MyShipmentsStatusChip({
    super.key,
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = BiTasiColors.primaryBlue;
        label = 'Aktif';
        break;
      default:
        color = Colors.grey;
        label = 'Aktif';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
