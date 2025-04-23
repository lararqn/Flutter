import 'package:flutter/material.dart';

class ItemDetailPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const ItemDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item['title'] ?? 'Geen titel'),
        backgroundColor: Colors.blueGrey,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item['imageUrls'] != null && item['imageUrls'].isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: item['imageUrls'].length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Image.network(
                        item['imageUrls'][index],
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.error),
                      ),
                    );
                  },
                ),
              )
            else
              const Icon(Icons.image_not_supported, size: 200),
            const SizedBox(height: 16),
            Text(
              item['title'] ?? 'Geen titel',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Beschrijving: ${item['description'] ?? 'Geen beschrijving'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Categorie: ${item['category'] ?? 'Onbekend'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Optie: ${item['rentOption'] ?? 'Te leen'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (item['rentOption'] == 'Te huur') ...[
              Text(
                'Prijs per dag: €${item['pricePerDay']?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Extra dag: €${item['extraDayPrice']?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}