class MessageModel {
  final String id;
  final String senderId;
  final String content;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    DateTime parseCreatedAt(dynamic raw) {
      DateTime? parsed;

      if (raw is DateTime) {
        parsed = raw;
      } else if (raw is int) {
        final ms = raw < 1000000000000 ? raw * 1000 : raw;
        parsed = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      } else if (raw is double) {
        final asInt = raw.toInt();
        final ms = asInt < 1000000000000 ? asInt * 1000 : asInt;
        parsed = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      } else {
        final s = raw?.toString();
        if (s != null) {
          final numeric = int.tryParse(s);
          if (numeric != null) {
            final ms = numeric < 1000000000000 ? numeric * 1000 : numeric;
            parsed = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
          } else {
            parsed = DateTime.tryParse(s);
          }
        }
      }

      final dt = parsed ?? DateTime.now();
      return dt.isUtc ? dt.toLocal() : dt;
    }

    return MessageModel(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: parseCreatedAt(json['createdAt']),
    );
  }
}


