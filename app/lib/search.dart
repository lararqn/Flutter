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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
// #region zoekbalk
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
//#endregion

      body: FutureBuilder<DocumentSnapshot>(
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

// #region categorielijst
          final categories = snapshot.data!.data() as Map<String, dynamic>;

          final filteredCategories = categories.keys
              .where((category) =>
                  category.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();

          return ListView.builder(
            itemCount: filteredCategories.length,
            itemBuilder: (context, index) {
              final categoryName = filteredCategories[index];
              const arrowIcon = Icon(Icons.chevron_right, color: Color(0xFF4A4A4A));

              return Column(
                children: [
                  ListTile(
                    title: Text(
                      categoryName,
                      style: const TextStyle(fontSize: 15, color: Color(0xFF4A4A4A)),
                    ),
                    trailing: arrowIcon,
                  ),
                  const Divider(color: Colors.grey, thickness: 0.2),
                ],
              );
            },
          );
//#endregion
        },
      ),
    );
  }
}
