import 'package:flutter/material.dart';

class MyShipmentsScreen extends StatelessWidget {
  const MyShipmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kargo Hareketleri")),
      body: const Center(child: Text("Aktif ve Geçmiş Kargolar Listesi")),
    );
  }
}