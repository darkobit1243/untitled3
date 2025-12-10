import 'package:flutter/material.dart';

/// Tek bir kargoya ait detay ekranı için placeholder.
///
/// Şu an projede kullanılmıyor ama gelecekte bir gönderinin
/// durumunu / hareketlerini göstermek için genişletilebilir.
class MyShipmentScreen extends StatelessWidget {
  const MyShipmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kargo Detayı')),
      body: const Center(child: Text('Kargo detayı ekranı (yakında).')),
    );
  }
}