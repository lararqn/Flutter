import 'package:app/ItemDetailPage.dart';
import 'package:app/categoryItems.dart';
import 'package:app/strings.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showItemDetails(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailPage(item: item),
      ),
    );
  }

  Future<String> _getLocationName(GeoPoint? location) async {
    if (location == null) return 'Onbekende locatie';
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

  bool _isItemAvailable(Map<String, dynamic> item) {
    final available = item['available'] as bool? ?? true;
    final availableDates = item['availableDates'] as List<dynamic>? ?? [];
    bool isCurrentlyBooked = availableDates.any((range) {
      DateTime start = (range['startDate'] as Timestamp).toDate();
      DateTime end = (range['endDate'] as Timestamp).toDate();
      DateTime now = DateTime.now();
      return now.isAfter(start.subtract(const Duration(days: 1))) && now.isBefore(end.add(const Duration(days: 1)));
    });
    return available && !isCurrentlyBooked;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zoeken'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Zoek items...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Items')
                  .where('available', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Fout bij ophalen items'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Geen items gevonden'));
                }

                final items = snapshot.data!.docs.where((doc) {
                  var item = doc.data() as Map<String, dynamic>;
                  final title = item['title']?.toString().toLowerCase() ?? '';
                  final description = item['description']?.toString().toLowerCase() ?? '';
                  return title.contains(_searchQuery) || description.contains(_searchQuery);
                }).toList();

                if (items.isEmpty) {
                  return const Center(child: Text('Geen overeenkomsten gevonden'));
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    var item = items[index].data() as Map<String, dynamic>;
                    bool isAvailable = _isItemAvailable(item);

                    return FutureBuilder<String>(
                      future: _getLocationName(item['location'] as GeoPoint?),
                      builder: (context, locationSnapshot) {
                        String locationName = locationSnapshot.data ?? 'Locatie laden...';
                        return ListTile(
                          leading: item['imageUrls'] != null && item['imageUrls'].isNotEmpty
                              ? Image.network(
                                  item['imageUrls'][0],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
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
                              Text('Locatie: $locationName'),
                              Text(
                                'Beschikbaarheid: ${isAvailable ? 'Beschikbaar' : 'Niet beschikbaar'}',
                                style: TextStyle(
                                  color: isAvailable ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _showItemDetails(item),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}