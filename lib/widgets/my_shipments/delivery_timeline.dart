import 'package:flutter/material.dart';

import '../../theme/bitasi_theme.dart';

class DeliveryTimeline extends StatelessWidget {
  const DeliveryTimeline({
    super.key,
    required this.status,
    required this.createdAt,
    required this.pickupAt,
    required this.deliveredAt,
    required this.disputedAt,
  });

  final String status;
  final DateTime? createdAt;
  final DateTime? pickupAt;
  final DateTime? deliveredAt;
  final DateTime? disputedAt;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    final steps = <_StepData>[
      _StepData(
        title: 'Oluşturuldu',
        done: createdAt != null,
        active: normalized == 'pickup_pending',
        time: createdAt,
      ),
      _StepData(
        title: 'Alındı',
        done: pickupAt != null || _isAfterPickup(normalized),
        active: normalized == 'in_transit',
        time: pickupAt,
      ),
      _StepData(
        title: 'Kapıda',
        done: normalized == 'at_door' || normalized == 'delivered' || normalized == 'disputed',
        active: normalized == 'at_door',
        time: null,
      ),
      _StepData(
        title: 'Teslim Edildi',
        done: deliveredAt != null || normalized == 'delivered' || normalized == 'disputed',
        active: normalized == 'delivered',
        time: deliveredAt,
      ),
      if (normalized == 'disputed' || disputedAt != null)
        _StepData(
          title: 'Uyuşmazlık',
          done: true,
          active: normalized == 'disputed',
          time: disputedAt,
        ),
    ];

    return Column(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _TimelineRow(step: steps[i], isLast: i == steps.length - 1),
          if (i != steps.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  bool _isAfterPickup(String normalized) {
    return normalized == 'in_transit' || normalized == 'at_door' || normalized == 'delivered' || normalized == 'disputed';
  }
}

class _StepData {
  const _StepData({
    required this.title,
    required this.done,
    required this.active,
    required this.time,
  });

  final String title;
  final bool done;
  final bool active;
  final DateTime? time;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.isLast});

  final _StepData step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Color color = step.active ? BiTasiColors.primaryRed : (step.done ? BiTasiColors.successGreen : Colors.grey);

    final icon = step.done ? Icons.check_circle : (step.active ? Icons.radio_button_checked : Icons.radio_button_unchecked);

    final timeText = step.time == null ? null : _format(step.time!);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(icon, color: color, size: 20),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                margin: const EdgeInsets.only(top: 4),
                color: Colors.black.withValues(alpha: 0.08),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(step.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (timeText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(timeText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _format(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    final local = dt.toLocal();
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}
