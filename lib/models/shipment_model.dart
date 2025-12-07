// models/shipment_model.dart

enum ShipmentStatus { pending, offered, accepted, inTransit, delivered, completed, cancelled }

class Shipment {
  final String id;
  final String senderId;
  final String? carrierId; // Teklif kabul edilince dolacak
  final String title;
  final String description;
  final String imageUrl;
  final String originCity;
  final String destinationCity;
  final double offeredPrice; // Göndericinin önerdiği
  final double? agreedPrice; // Anlaşılan fiyat
  final ShipmentStatus status;
  final bool isContractAccepted; // Yasal sözleşme onayı
  final DateTime createdAt;

  Shipment({
    required this.id,
    required this.senderId,
    this.carrierId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.originCity,
    required this.destinationCity,
    required this.offeredPrice,
    this.agreedPrice,
    this.status = ShipmentStatus.pending,
    this.isContractAccepted = false,
    required this.createdAt,
  });

  // Firebase'den veri çekerken ve gönderirken kullanılacak toMap ve fromMap metodları buraya gelecek...
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'carrierId': carrierId,
      'title': title,
      'originCity': originCity,
      'destinationCity': destinationCity,
      'status': status.name,
      // ... diğer alanlar
    };
  }
}