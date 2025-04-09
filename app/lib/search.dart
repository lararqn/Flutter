import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorieën'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('Categories').doc('1').get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator()); 
          }

          if (snapshot.hasError) {
            return Center(child: Text('Er is een fout opgetreden: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Geen categorieën gevonden.'));
          }
          final categories = snapshot.data!.data() as Map<String, dynamic>;
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final categoryName = categories.keys.elementAt(index);
              const arrowIcon = Icon(Icons.chevron_right, color: Colors.grey);

              return Column(
                children: [
                  ListTile(
                    title: InkWell(
                      onTap: () {
                      },
                      child: Text(
                        categoryName,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    trailing: arrowIcon,
                  ),
                  const Divider( 
                    color: Colors.grey,
                    thickness: 0.2,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
