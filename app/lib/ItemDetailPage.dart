import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class ItemDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const ItemDetailPage({super.key, required this.item});

  @override
  _ItemDetailPageState createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime _focusedDay = DateTime.now();
  List<DateTime> _bookedDates = [];
  bool _isLoading = false;
  String? _locationName;
  bool _isAvailable = true;
  String? _ownerName;

  @override
  void initState() {
    super.initState();
    _loadBookedDates();
    _getLocationName();
    _checkAvailability();
    _getOwnerName();
  }

  Future<void> _loadBookedDates() async {
    final bookedDates = widget.item['bookedDates'] as List<dynamic>? ?? [];
    List<DateTime> booked = [];
    for (var range in bookedDates) {
      DateTime start = (range['startDate'] as Timestamp).toDate();
      DateTime end = (range['endDate'] as Timestamp).toDate();
      for (DateTime date = start; 
           date.isBefore(end.add(Duration(days: 1))); 
           date = date.add(Duration(days: 1))) {
        booked.add(date);
      }
    }
    setState(() {
      _bookedDates = booked;
    });
  }

  Future<void> _getLocationName() async {
    try {
      final location = widget.item['location'] as GeoPoint?;
      if (location == null) {
        setState(() {
          _locationName = widget.item['locationName'] ?? 'Locatie niet opgegeven';
        });
        return;
      }
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        setState(() {
          _locationName = placemark.locality ?? placemark.subAdministrativeArea ?? 'Onbekende locatie';
        });
      } else {
        setState(() {
          _locationName = 'Onbekende locatie';
        });
      }
    } catch (e) {
      setState(() {
        _locationName = 'Locatie niet beschikbaar: $e';
      });
    }
  }

  Future<void> _getOwnerName() async {
    try {
      final ownerId = widget.item['ownerId'] as String?;
      if (ownerId == null) {
        setState(() {
          _ownerName = 'Onbekende verhuurder';
        });
        return;
      }
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(ownerId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _ownerName = userData['displayName'] ?? 'Onbekende verhuurder';
        });
      } else {
        setState(() {
          _ownerName = 'Onbekende verhuurder';
        });
      }
    } catch (e) {
      setState(() {
        _ownerName = 'Fout bij ophalen verhuurder: $e';
      });
    }
  }

  void _checkAvailability() {
    final available = widget.item['available'] as bool? ?? true;
    final bookedDates = widget.item['bookedDates'] as List<dynamic>? ?? [];
    bool isCurrentlyBooked = bookedDates.any((range) {
      DateTime start = (range['startDate'] as Timestamp).toDate();
      DateTime end = (range['endDate'] as Timestamp).toDate();
      DateTime now = DateTime.now();
      return now.isAfter(start.subtract(const Duration(days: 1))) && 
             now.isBefore(end.add(const Duration(days: 1)));
    });
    setState(() {
      _isAvailable = available && !isCurrentlyBooked;
    });
  }

  bool _isDateBooked(DateTime day) {
    return _bookedDates.any((date) =>
        date.year == day.year &&
        date.month == day.month &&
        date.day == day.day);
  }

  Future<bool> _checkDateConflict(DateTime start, DateTime end) async {
    final bookedDates = widget.item['bookedDates'] as List<dynamic>? ?? [];
    for (var range in bookedDates) {
      DateTime bookedStart = (range['startDate'] as Timestamp).toDate();
      DateTime bookedEnd = (range['endDate'] as Timestamp).toDate();
      if (start.isBefore(bookedEnd.add(Duration(days: 1))) && end.isAfter(bookedStart.subtract(Duration(days: 1)))) {
        return true; 
      }
    }
    return false; 
  }

  Future<void> _requestRental() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecteer een huurperiode.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Je moet ingelogd zijn om te huren.')),
      );
      return;
    }

    if (user.uid == widget.item['ownerId']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Je kunt je eigen item niet huren.')),
      );
      return;
    }

    bool hasConflict = await _checkDateConflict(_startDate!, _endDate!);
    if (hasConflict) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geselecteerde datums overlappen met een bestaande reservering.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String itemId = widget.item['id'] ?? (await _getItemId());

      await FirebaseFirestore.instance.collection('Reservations').add({
        'itemId': itemId,
        'userId': user.uid,
        'ownerId': widget.item['ownerId'],
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'deletedBy': [],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Huurverzoek succesvol ingediend!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij indienen huurverzoek: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _getItemId() async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('Items')
        .where('title', isEqualTo: widget.item['title'])
        .where('ownerId', isEqualTo: widget.item['ownerId'])
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }
    throw Exception('Item niet gevonden');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item['title'] ?? 'Geen titel'),
        backgroundColor: Colors.blueGrey,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.item['imageUrls'] != null && widget.item['imageUrls'].isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.item['imageUrls'].length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Image.network(
                        widget.item['imageUrls'][index],
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
              widget.item['title'] ?? 'Geen titel',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Beschrijving: ${widget.item['description'] ?? 'Geen beschrijving'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Categorie: ${widget.item['category'] ?? 'Onbekend'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Locatie: ${_locationName ?? 'Locatie laden...'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Verhuurder: ${_ownerName ?? 'Naam laden...'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Beschikbaarheid: ${_isAvailable ? 'Beschikbaar' : 'Niet beschikbaar'}',
              style: TextStyle(
                fontSize: 16,
                color: _isAvailable ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Optie: ${widget.item['rentOption'] ?? 'Te leen'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (widget.item['rentOption'] == 'Te huur') ...[
              Text(
                'Prijs per dag: €${widget.item['pricePerDay']?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Extra dag: €${widget.item['extraDayPrice']?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Selecteer huurperiode:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) {
                if (_startDate == null) return false;
                if (_endDate == null) return isSameDay(day, _startDate);
                return (day.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
                    day.isBefore(_endDate!.add(const Duration(days: 1))));
              },
              calendarStyle: const CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Colors.blueGrey,
                  shape: BoxShape.circle,
                ),
                rangeStartDecoration: BoxDecoration(
                  color: Colors.blueGrey,
                  shape: BoxShape.circle,
                ),
                rangeEndDecoration: BoxDecoration(
                  color: Colors.blueGrey,
                  shape: BoxShape.circle,
                ),
                withinRangeDecoration: BoxDecoration(
                  color: Colors.blueGrey,
                  shape: BoxShape.rectangle,
                ),
                disabledDecoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                disabledTextStyle: TextStyle(color: Colors.white),
              ),
              enabledDayPredicate: (day) => !_isDateBooked(day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  if (_startDate == null || (_startDate != null && _endDate != null)) {
                    _startDate = selectedDay;
                    _endDate = null;
                  } else if (selectedDay.isBefore(_startDate!)) {
                    _startDate = selectedDay;
                    _endDate = null;
                  } else {
                    _endDate = selectedDay;
                  }
                  _focusedDay = focusedDay;
                });
              },
              rangeStartDay: _startDate,
              rangeEndDay: _endDate,
            ),
            const SizedBox(height: 16),
            if (_startDate != null)
              Text(
                'Van: ${DateFormat('dd/MM/yyyy').format(_startDate!)}',
                style: const TextStyle(fontSize: 16),
              ),
            if (_endDate != null)
              Text(
                'Tot: ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _requestRental,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 0),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Huurverzoek indienen',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}