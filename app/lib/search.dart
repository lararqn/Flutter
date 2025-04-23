import 'package:app/ItemDetailPage.dart';
import 'package:app/categoryItems.dart';
import 'package:app/strings.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
          // Zoekresultaten
          if (_searchQuery.isNotEmpty)
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
                      var item = filteredDocs[index].data() as Map<String, dynamic>;
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
                        onTap: () => _showItemDetails(item),
                      );
                    },
                  );
                },
              ),
            )
          else
            // Categorielijst
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