import 'package:flutter/material.dart';

import '../../theme/bitasi_theme.dart';

class SupportFaqScreen extends StatelessWidget {
  const SupportFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Destek & SSS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _FaqTile(
            title: 'Teslimatım neden gecikiyor?',
            body: 'Taşıyıcının konum/takip durumu ve rota yoğunluğuna göre gecikmeler olabilir. Canlı takip açıksa haritadan ilerlemeyi görebilirsin.',
          ),
          _FaqTile(
            title: 'Sorun bildirimi nasıl açarım?',
            body: 'Teslimat detay ekranından “Sorun Bildir” seçeneğini kullanabilirsin. Teslimat “Teslim edildi” durumundayken uyuşmazlık açılabilir.',
          ),
          _FaqTile(
            title: 'Ödeme/IBAN bilgilerim nerede?',
            body: 'Profil ekranında “Ödeme Bilgileri” bölümünden ödeme yöntemini ekleyebilir veya güncelleyebilirsin.',
          ),
          SizedBox(height: 12),
          Text(
            'Daha fazla yardıma ihtiyacın olursa destek ekibine ulaş.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          SizedBox(height: 8),
          _SupportCard(),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(body, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: const [
            Icon(Icons.support_agent, color: BiTasiColors.primaryRed),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Destek: Uygulama içi mesajlaşma veya e-posta kanalıyla yardımcı oluruz.',
                style: TextStyle(color: BiTasiColors.textDarkGrey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
