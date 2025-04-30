import 'dart:convert';
import 'package:app/ItemDetailPage.dart';
import 'package:app/editItemPage.dart';
import 'package:app/index.dart';
import 'package:app/strings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showItemDetails(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ItemDetailPage(item: item)),
    );
  }

  void _editItem(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditItemPage(item: item)),
    );
  }

  Future<void> _deleteItem(String itemId) async {
    // try {
    await FirebaseFirestore.instance.collection('Items').doc(itemId).delete();

    final reservationsSnapshot =
        await FirebaseFirestore.instance
            .collection('Reservations')
            .where('itemId', isEqualTo: itemId)
            .get();
    for (var doc in reservationsSnapshot.docs) {
      await doc.reference.delete();
    }
    //werkt nog niet zo goed items worden wel verwijderd maar er komt nog een error?
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(content: Text('Item succesvol verwijderd')),
    // );
    // } catch (e) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('Fout bij verwijderen item: $e')),
    //   );
    // }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uitgelogd')));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const IndexPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppStrings.user)),
        body: const Center(child: Text('Geen gebruiker ingelogd')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.user),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Mijn Items'), Tab(text: 'Gereserveerd')],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseFirestore.instance
                      .collection('Users')
                      .doc(_currentUser!.uid)
                      .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                if (snapshot.hasError) {
                  return const Center(child: Icon(Icons.error, size: 40));
                }

                Widget defaultUserInfo() {
                  return Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey[300],
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentUser?.displayName ?? 'Geen naam',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentUser?.email ?? 'Geen e-mail',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF383838),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          minimumSize: const Size(120, 0),
                        ),
                        child: const Text(
                          'Uitloggen',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  );
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return defaultUserInfo();
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final photoBase64 = data['photoBase64'] as String?;

                return Column(
                  children: [
                    photoBase64 != null && photoBase64.isNotEmpty
                        ? CircleAvatar(
                          radius: 40,
                          backgroundImage: MemoryImage(
                            base64Decode(
                              photoBase64.startsWith('data:image/jpeg;base64,')
                                  ? photoBase64.substring(23)
                                  : photoBase64,
                            ),
                          ),
                        )
                        : CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[300],
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                    const SizedBox(height: 16),
                    Text(
                      _currentUser?.displayName ?? 'Geen naam',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentUser?.email ?? 'Geen e-mail',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF383838),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        minimumSize: const Size(120, 0),
                      ),
                      child: const Text(
                        'Uitloggen',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('Items')
                          .where('ownerId', isEqualTo: _currentUser?.uid)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Fout bij ophalen items'),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Geen items geüpload'));
                    }

                    final items = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        var itemData =
                            items[index].data() as Map<String, dynamic>;
                        var item = {...itemData, 'id': items[index].id};
                        return ListTile(
                          leading:
                              item['imageUrls'] != null &&
                                      item['imageUrls'].isNotEmpty
                                  ? Image.network(
                                    item['imageUrls'][0],
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(Icons.error),
                                  )
                                  : const Icon(Icons.image),
                          title: Text(item['title'] ?? 'Geen titel'),
                          subtitle: Text(
                            item['rentOption'] == 'Te huur'
                                ? '€${item['pricePerDay']?.toStringAsFixed(2) ?? '0.00'} / dag'
                                : 'Gratis (Te leen)',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blueGrey,
                                ),
                                onPressed: () => _editItem(item),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteItem(item['id']),
                              ),
                            ],
                          ),
                          onTap: () => _showItemDetails(item),
                        );
                      },
                    );
                  },
                ),
                StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('Reservations')
                          .where('userId', isEqualTo: _currentUser?.uid)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Fout bij ophalen reserveringen'),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('Geen gereserveerde items'),
                      );
                    }

                    final reservations = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: reservations.length,
                      itemBuilder: (context, index) {
                        var reservation =
                            reservations[index].data() as Map<String, dynamic>;
                        var itemId = reservation['itemId'];

                        return FutureBuilder<DocumentSnapshot>(
                          future:
                              FirebaseFirestore.instance
                                  .collection('Items')
                                  .doc(itemId)
                                  .get(),
                          builder: (context, itemSnapshot) {
                            if (itemSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const ListTile(
                                leading: CircularProgressIndicator(),
                                title: Text('Laden...'),
                              );
                            }
                            if (itemSnapshot.hasError ||
                                !itemSnapshot.hasData ||
                                !itemSnapshot.data!.exists) {
                              return const ListTile(
                                leading: Icon(Icons.error),
                                title: Text('Item niet gevonden'),
                              );
                            }

                            var itemData =
                                itemSnapshot.data!.data()
                                    as Map<String, dynamic>;
                            var item = {
                              ...itemData,
                              'id': itemSnapshot.data!.id,
                            };
                            return ListTile(
                              leading:
                                  item['imageUrls'] != null &&
                                          item['imageUrls'].isNotEmpty
                                      ? Image.network(
                                        item['imageUrls'][0],
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
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
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
