import 'package:app/ItemDetailPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

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

  Future<String> _getLocationName(GeoPoint? location) async {
    if (location == null) return 'Locatie niet opgegeven';
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return placemark.locality ?? placemark.subAdministrativeArea ?? 'Onbekende locatie';
      }
      return 'Onbekende locatie';
    } catch (e) {
      return 'Locatie niet beschikbaar';
    }
  }

  Future<String> _getOwnerName(String? ownerId) async {
    if (ownerId == null) return 'Onbekende verhuurder';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(ownerId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['displayName'] ?? 'Onbekende verhuurder';
      }
      return 'Onbekende verhuurder';
    } catch (e) {
      return 'Fout bij ophalen verhuurder: $e';
    }
  }

  bool _isItemAvailable(Map<String, dynamic> item) {
    final available = item['available'] as bool? ?? true;
    final bookedDates = item['bookedDates'] as List<dynamic>? ?? [];
    bool isCurrentlyBooked = bookedDates.any((range) {
      DateTime start = (range['startDate'] as Timestamp).toDate();
      DateTime end = (range['endDate'] as Timestamp).toDate();
      DateTime now = DateTime.now();
      return now.isAfter(start.subtract(const Duration(days: 1))) && 
             now.isBefore(end.add(const Duration(days: 1)));
    });
    return available && !isCurrentlyBooked;
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
              var itemData = items[index].data() as Map<String, dynamic>;
              var item = {
                ...itemData,
                'id': items[index].id,
              };
              bool isAvailable = _isItemAvailable(item);

              return FutureBuilder<List<dynamic>>(
                future: Future.wait([
                  _getLocationName(item['location'] as GeoPoint?),
                  _getOwnerName(item['ownerId'] as String?),
                ]),
                builder: (context, snapshot) {
                  String locationName = snapshot.data?[0] ?? 'Locatie laden...';
                  String ownerName = snapshot.data?[1] ?? 'Verhuurder laden...';

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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['rentOption'] == 'Te huur'
                              ? '€${item['pricePerDay']?.toStringAsFixed(2) ?? '0.00'} / dag'
                              : 'Gratis (Te leen)',
                        ),
                        Text('Verhuurder: $ownerName'),
                        Text('Locatie: $locationName'),
                        Text(
                          'Beschikbaarheid: ${isAvailable ? 'Beschikbaar' : 'Niet beschikbaar'}',
                          style: TextStyle(
                            color: isAvailable ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showItemDetails(context, item),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}