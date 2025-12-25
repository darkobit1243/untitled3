import 'package:flutter/material.dart';

class UserProfileSheet extends StatelessWidget {
  const UserProfileSheet({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: (data['avatarUrl'] as String?) != null
                    ? NetworkImage(data['avatarUrl'] as String)
                    : null,
                child: (data['avatarUrl'] == null)
                    ? Text(
                        (data['fullName']?.toString().isNotEmpty ?? false)
                            ? data['fullName'].toString().characters.first.toUpperCase()
                            : 'U',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['fullName']?.toString() ?? data['email']?.toString() ?? 'Kullanıcı',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (data['rating'] != null)
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          Text(data['rating'].toString(), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (data['deliveredCount'] != null) Text('Tamamlanan teslimat: ${data['deliveredCount']}'),
          if (data['address'] != null) Text('Adres: ${data['address']}'),
          if (data['phone'] != null) Text('Telefon: ${data['phone']}'),
        ],
      ),
    );
  }
}
