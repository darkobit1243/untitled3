import 'package:flutter/material.dart';

import '../../models/delivery_status.dart';
import '../../theme/bitasi_theme.dart';

class MyShipmentsSimpleTimeline extends StatelessWidget {
  const MyShipmentsSimpleTimeline({
    super.key,
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final steps = const [
      _TimelineStep(DeliveryStatus.pickupPending, 'Alım bekleniyor'),
      _TimelineStep(DeliveryStatus.inTransit, 'Yolda'),
      _TimelineStep(DeliveryStatus.delivered, 'Teslim edildi'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.map((step) {
        final isDone = _isStepDone(status, step.key);
        final isCurrent = status == step.key;
        final color = isDone ? BiTasiColors.successGreen : (isCurrent ? BiTasiColors.primaryBlue : Colors.grey);
        return Row(
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isDone || isCurrent ? color : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              step.label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  bool _isStepDone(String status, String key) {
    final order = [
      DeliveryStatus.pickupPending,
      DeliveryStatus.inTransit,
      DeliveryStatus.delivered,
    ];
    final currentIndex = order.indexOf(status);
    final stepIndex = order.indexOf(key);
    if (currentIndex == -1 || stepIndex == -1) return false;
    return currentIndex >= stepIndex;
  }
}

class _TimelineStep {
  final String key;
  final String label;
  const _TimelineStep(this.key, this.label);
}
