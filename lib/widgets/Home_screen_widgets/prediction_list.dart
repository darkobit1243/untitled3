import 'package:flutter/material.dart';

/// Basit bir yer tahmini listesi widget'ı.
class PredictionList extends StatelessWidget {
  const PredictionList({super.key, required this.placePredictions, required this.onPlaceSelected});

  final List<dynamic> placePredictions;
  final void Function(String placeId, String description) onPlaceSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        shrinkWrap: true,
        itemCount: placePredictions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = placePredictions[index] as Map<String, dynamic>;
          final description = item['description']?.toString() ?? '';
          return ListTile(
            leading: const Icon(Icons.location_on_outlined, color: Colors.redAccent),
            title: Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              final placeId = item['place_id']?.toString();
              if (placeId != null) {
                onPlaceSelected(placeId, description);
              }
            },
          );
        },
      ),
    );
  }
}
