import 'package:app/ItemDetailPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CategoryItemsPage extends StatelessWidget {
  final String category;

  const CategoryItemsPage({super.key, required this.category});

  void _showItemDetails(BuildContext context, Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailPage(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category),
        backgroundColor: Colors.blueGrey,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Items')
            .where('available', isEqualTo: true)
            .where('category', isEqualTo: category)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Fout bij ophalen items'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Geen items gevonden in deze categorie'));
          }

          final items = snapshot.data!.docs;

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              var item = items[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: item['imageUrls'] != null && item['imageUrls'].isNotEmpty
                    ? Image.network(
                        item['imageUrls'][0],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.error),
                      )
                    : const Icon(Icons.image),
                title: Text(item['title'] ?? 'Geen titel'),
                subtitle: Text(
                  item['rentOption'] == 'Te huur'
                      ? '€${item['pricePerDay']?.toStringAsFixed(2) ?? '0.00'} / dag'
                      : 'Gratis (Te leen)',
                ),
                onTap: () => _showItemDetails(context, item),
              );
            },
          );
        },
      ),
    );
  }
}