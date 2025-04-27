import 'package:flutter/material.dart';
import 'package:app/strings.dart';  
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app/ItemDetailPage.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  _InboxPageState createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> with SingleTickerProviderStateMixin {
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
      MaterialPageRoute(
        builder: (context) => ItemDetailPage(item: item),
      ),
    );
  }

  Future<void> _approveReservation(String reservationId, String itemId, DateTime startDate, DateTime endDate) async {
    try {
      await FirebaseFirestore.instance.collection('Reservations').doc(reservationId).update({
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('Items').doc(itemId).update({
        'bookedDates': FieldValue.arrayUnion([
          {
            'startDate': Timestamp.fromDate(startDate),
            'endDate': Timestamp.fromDate(endDate),
          }
        ]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservering goedgekeurd')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij goedkeuren: $e')),
      );
    }
  }

  Future<void> _rejectReservation(String reservationId) async {
    try {
      await FirebaseFirestore.instance.collection('Reservations').doc(reservationId).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservering afgewezen')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij afwijzen: $e')),
      );
    }
  }

  Future<void> _cancelReservation(String reservationId) async {
    try {
      await FirebaseFirestore.instance.collection('Reservations').doc(reservationId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservering geannuleerd')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij annuleren: $e')),
      );
    }
  }

  Future<void> _deleteReservation(String reservationId) async {
    try {
      await FirebaseFirestore.instance.collection('Reservations').doc(reservationId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservering verwijderd')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij verwijderen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.inbox)),
        body: const Center(child: Text('Geen gebruiker ingelogd')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.inbox),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Verzonden'),
            Tab(text: 'Ontvangen'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Reservations')
                .where('userId', isEqualTo: _currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Fout bij ophalen reserveringen'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Geen verzonden reserveringen'));
              }

              final reservations = snapshot.data!.docs;

              return ListView.builder(
                itemCount: reservations.length,
                itemBuilder: (context, index) {
                  var reservation = reservations[index].data() as Map<String, dynamic>;
                  var reservationId = reservations[index].id;
                  var itemId = reservation['itemId'];
                  var status = reservation['status'] ?? 'pending';
                  var startDate = (reservation['startDate'] as Timestamp).toDate();
                  var endDate = (reservation['endDate'] as Timestamp).toDate();

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('Items').doc(itemId).get(),
                    builder: (context, itemSnapshot) {
                      if (itemSnapshot.connectionState == ConnectionState.waiting) {
                        return const ListTile(
                          leading: CircularProgressIndicator(),
                          title: Text('Laden...'),
                        );
                      }
                      if (itemSnapshot.hasError || !itemSnapshot.hasData || !itemSnapshot.data!.exists) {
                        return const ListTile(
                          leading: Icon(Icons.error),
                          title: Text('Item niet gevonden'),
                        );
                      }

                      var itemData = itemSnapshot.data!.data() as Map<String, dynamic>;
                      var item = {
                        ...itemData,
                        'id': itemSnapshot.data!.id,
                      };

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
                              'Van: ${DateFormat('dd/MM/yyyy').format(startDate)} tot ${DateFormat('dd/MM/yyyy').format(endDate)}',
                            ),
                            Text(
                              'Status: ${status == 'pending' ? 'In afwachting' : status == 'approved' ? 'Goedgekeurd' : status == 'rejected' ? 'Afgewezen' : 'Geannuleerd'}',
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status == 'pending' || status == 'approved')
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () => _cancelReservation(reservationId),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () => _deleteReservation(reservationId),
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
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Reservations')
                .where('ownerId', isEqualTo: _currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Fout bij ophalen reserveringen'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Geen ontvangen reserveringen'));
              }

              final reservations = snapshot.data!.docs;

              return ListView.builder(
                itemCount: reservations.length,
                itemBuilder: (context, index) {
                  var reservation = reservations[index].data() as Map<String, dynamic>;
                  var reservationId = reservations[index].id;
                  var itemId = reservation['itemId'];
                  var status = reservation['status'] ?? 'pending';
                  var startDate = (reservation['startDate'] as Timestamp).toDate();
                  var endDate = (reservation['endDate'] as Timestamp).toDate();

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('Items').doc(itemId).get(),
                    builder: (context, itemSnapshot) {
                      if (itemSnapshot.connectionState == ConnectionState.waiting) {
                        return const ListTile(
                          leading: CircularProgressIndicator(),
                          title: Text('Laden...'),
                        );
                      }
                      if (itemSnapshot.hasError || !itemSnapshot.hasData || !itemSnapshot.data!.exists) {
                        return const ListTile(
                          leading: Icon(Icons.error),
                          title: Text('Item niet gevonden'),
                        );
                      }

                      var itemData = itemSnapshot.data!.data() as Map<String, dynamic>;
                      var item = {
                        ...itemData,
                        'id': itemSnapshot.data!.id,
                      };

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
                              'Van: ${DateFormat('dd/MM/yyyy').format(startDate)} tot ${DateFormat('dd/MM/yyyy').format(endDate)}',
                            ),
                            Text(
                              'Status: ${status == 'pending' ? 'In afwachting' : status == 'approved' ? 'Goedgekeurd' : status == 'rejected' ? 'Afgewezen' : 'Geannuleerd'}',
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status == 'pending')
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    onPressed: () => _approveReservation(reservationId, itemId, startDate, endDate),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () => _rejectReservation(reservationId),
                                  ),
                                ],
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () => _deleteReservation(reservationId),
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
        ],
      ),
    );
  }
}