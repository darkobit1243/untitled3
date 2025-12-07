// services/shipment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/shipment_model.dart';
// Model import edildi varsayalım

class ShipmentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. İlan Oluşturma (Gönderici)
  Future<void> createShipment(String userId, String title, String from, String to, double price, String imageUrl) async {
    String shipmentId = const Uuid().v4();

    Shipment newShipment = Shipment(
      id: shipmentId,
      senderId: userId,
      title: title,
      description: "Kutu içeriği...",
      imageUrl: imageUrl,
      originCity: from,
      destinationCity: to,
      offeredPrice: price,
      createdAt: DateTime.now(),
    );

    await _db.collection('shipments').doc(shipmentId).set(newShipment.toMap());
  }

  // 2. Teklif Verme (Taşıyıcı)
  // Bu ayrı bir 'offers' koleksiyonunda tutulmalı ki bir ilana birden fazla teklif gelebilsin.
  Future<void> placeOffer(String shipmentId, String carrierId, double bidAmount) async {
    await _db.collection('shipments').doc(shipmentId).collection('offers').add({
      'carrierId': carrierId,
      'bidAmount': bidAmount,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'waiting', // waiting, accepted, rejected
    });
  }

  // 3. Teklifi Kabul Etme ve Sözleşme (Kritik Nokta)
  Future<void> acceptOfferAndSignContract(String shipmentId, String carrierId, double finalPrice) async {
    // Transaction kullanarak işlemin güvenli olmasını sağlarız
    await _db.runTransaction((transaction) async {
      DocumentReference shipmentRef = _db.collection('shipments').doc(shipmentId);

      // İlanı güncelle
      transaction.update(shipmentRef, {
        'carrierId': carrierId,
        'agreedPrice': finalPrice,
        'status': ShipmentStatus.accepted.name, // Artık eşleşme sağlandı
        'isContractAccepted': true, // Kullanıcı arayüzde checkbox'ı işaretlediğinde bu metod çağrılır
      });

      // Burada ödeme sistemi API'si (Stripe/Iyzico) tetiklenir ve para bloke edilir.
    });
  }
}