import 'package:flutter/material.dart';

import '../../theme/bitasi_theme.dart';
import 'auth_role_card.dart';

class AuthRoleSelectionView extends StatelessWidget {
  const AuthRoleSelectionView({
    super.key,
    required this.onSelectSender,
    required this.onSelectCarrier,
  });

  final VoidCallback onSelectSender;
  final VoidCallback onSelectCarrier;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nasıl kullanmak istiyorsun?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gönderici olarak kargo çıkabilir veya taşıyıcı olarak yolculuklarında ek gelir elde edebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            AuthRoleCard(
              icon: Icons.send_outlined,
              title: 'Gönderici',
              description: 'Paketlerini farklı şehirlere güvenle gönder.',
              color: BiTasiColors.primaryRed,
              onTap: onSelectSender,
            ),
            const SizedBox(height: 16),
            AuthRoleCard(
              icon: Icons.directions_car,
              title: 'Taşıyıcı',
              description: 'Yolculuklarını kazanca çevir, kargo taşı.',
              color: BiTasiColors.successGreen,
              onTap: onSelectCarrier,
            ),
          ],
        ),
      ),
    );
  }
}
