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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
            child: TextField(
              controller: _searchController,
              onChanged: (query) {
                setState(() {
                  _searchQuery = query;
                });
              },
              decoration: InputDecoration(
                hintText: AppStrings.searchPlaceholder,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.search, color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_searchQuery.isNotEmpty)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Items')
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

                  final filteredDocs = snapshot.data!.docs.where((doc) {
                    var item = doc.data() as Map<String, dynamic>;
                    final title = item['title']?.toString().toLowerCase() ?? '';
                    final description = item['description']?.toString().toLowerCase() ?? '';
                    return title.contains(_searchQuery.toLowerCase()) ||
                        description.contains(_searchQuery.toLowerCase());
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(child: Text('Geen items gevonden voor deze zoekterm'));
                  }

                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      var itemData = filteredDocs[index].data() as Map<String, dynamic>;
                      var item = {
                        ...itemData,
                        'id': filteredDocs[index].id,
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
                            onTap: () => _showItemDetails(item),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Categorieën',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('Categories').doc('1').get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Er is een fout opgetreden: ${snapshot.error}'),
                          );
                        }

                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Center(child: Text(AppStrings.noCategoriesFound));
                        }

                        final categories = snapshot.data!.data() as Map<String, dynamic>;
                        final categoryList = categories.keys.toList();

                        return ListView.builder(
                          itemCount: categoryList.length,
                          itemBuilder: (context, index) {
                            final categoryName = categoryList[index];
                            const arrowIcon = Icon(Icons.chevron_right, color: Color(0xFF4A4A4A));

                            return Column(
                              children: [
                                ListTile(
                                  title: Text(
                                    categoryName,
                                    style: const TextStyle(fontSize: 15, color: Color(0xFF4A4A4A)),
                                  ),
                                  trailing: arrowIcon,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CategoryItemsPage(category: categoryName),
                                      ),
                                    );
                                  },
                                ),
                                const Divider(color: Colors.grey, thickness: 0.2),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}