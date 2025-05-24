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

  static const Color _primaryColor = Color(0xFF333333);
  static const Color _accentColor = Color(0xFF4A4A4A);
  static const Color _borderColor = Color(0xFFDBDBDB);
  static const Color _inputFillColor = Color(0xFFFAFAFA);

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
      for (DateTime date = DateTime(start.year, start.month, start.day);
          date.isBefore(DateTime(end.year, end.month, end.day).add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))) {
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
      DateTime now = DateTime.now();
      return now.isAfter(DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1))) &&
             now.isBefore(DateTime(now.year, now.month, now.day).add(const Duration(days: 1)));
    });
    setState(() {
      _isAvailable = available && !isCurrentlyBooked;
    });
  }

  bool _isDateBooked(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _bookedDates.any((date) =>
        date.year == normalizedDay.year &&
        date.month == normalizedDay.month &&
        date.day == normalizedDay.day);
  }

  Future<bool> _checkDateConflict(DateTime start, DateTime end) async {
    final bookedDates = widget.item['bookedDates'] as List<dynamic>? ?? [];
    for (var range in bookedDates) {
      DateTime bookedStart = (range['startDate'] as Timestamp).toDate();
      DateTime bookedEnd = (range['endDate'] as Timestamp).toDate();
      final normalizedStart = DateTime(start.year, start.month, start.day);
      final normalizedEnd = DateTime(end.year, end.month, end.day);
      final normalizedBookedStart = DateTime(bookedStart.year, bookedStart.month, bookedStart.day);
      final normalizedBookedEnd = DateTime(bookedEnd.year, bookedEnd.month, bookedEnd.day);

      if (normalizedStart.isBefore(normalizedBookedEnd.add(const Duration(days: 1))) &&
          normalizedEnd.isAfter(normalizedBookedStart.subtract(const Duration(days: 1)))) {
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

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('De einddatum kan niet voor de startdatum liggen.')),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.item['title'] ?? 'Geen titel',
          style: const TextStyle(
            fontSize: 15,
            color: _primaryColor,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: _borderColor,
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.item['imageUrls'] != null && widget.item['imageUrls'].isNotEmpty)
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: _inputFillColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.item['imageUrls'].length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Image.network(
                          widget.item['imageUrls'][index],
                          width: MediaQuery.of(context).size.width - 32,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(child: Icon(Icons.broken_image, size: 50, color: _accentColor)),
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: _inputFillColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
                child: const Center(
                  child: Icon(Icons.image_not_supported, size: 100, color: _accentColor),
                ),
              ),
            const SizedBox(height: 24),

            Text(
              widget.item['title'] ?? 'Geen titel',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Beschrijving',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _primaryColor.withAlpha((255 * 0.8).round()),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.item['description'] ?? 'Geen beschrijving beschikbaar.',
              style: const TextStyle(fontSize: 16, color: _accentColor),
            ),
            const SizedBox(height: 24),

            _buildDetailRow(
              icon: Icons.category,
              label: 'Categorie',
              value: widget.item['category'] ?? 'Onbekend',
            ),
            _buildDetailRow(
              icon: Icons.location_on,
              label: 'Locatie',
              value: _locationName ?? 'Locatie laden...',
            ),
            _buildDetailRow(
              icon: Icons.person,
              label: 'Verhuurder',
              value: _ownerName ?? 'Naam laden...',
            ),
            _buildDetailRow(
              icon: Icons.check_circle_outline,
              label: 'Beschikbaarheid',
              value: _isAvailable ? 'Beschikbaar' : 'Niet beschikbaar',
              valueColor: _isAvailable ? Colors.green : Colors.red,
            ),
            _buildDetailRow(
              icon: Icons.swap_horiz,
              label: 'Optie',
              value: widget.item['rentOption'] ?? 'Te leen',
            ),

            if (widget.item['rentOption'] == 'Te huur') ...[
              _buildDetailRow(
                icon: Icons.euro,
                label: 'Prijs per dag',
                value: '€${widget.item['pricePerDay']?.toStringAsFixed(2) ?? '0.00'}',
              ),
              _buildDetailRow(
                icon: Icons.euro_symbol,
                label: 'Prijs per extra dag',
                value: '€${widget.item['extraDayPrice']?.toStringAsFixed(2) ?? '0.00'}',
              ),
            ],
            const SizedBox(height: 24),

            Text(
              'Selecteer huurperiode:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _primaryColor.withAlpha((255 * 0.8).round()),
              ),
            ),
            const SizedBox(height: 16),
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
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: const TextStyle(color: _primaryColor),
                defaultTextStyle: const TextStyle(color: _primaryColor),
                todayDecoration: BoxDecoration(
                  color: _accentColor.withAlpha((255 * 0.3).round()),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                ),
                rangeStartDecoration: const BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                ),
                rangeEndDecoration: const BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                ),
                withinRangeDecoration: BoxDecoration(
                  color: _primaryColor.withAlpha((255 * 0.1).round()),
                  shape: BoxShape.rectangle,
                ),
                disabledDecoration: BoxDecoration(
                  color: Colors.grey.withAlpha((255 * 0.4).round()),
                  shape: BoxShape.circle,
                ),
                disabledTextStyle: const TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.white,
                  decorationThickness: 2,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: _primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: _primaryColor),
                rightChevronIcon: Icon(Icons.chevron_right, color: _primaryColor),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: _accentColor, fontWeight: FontWeight.bold),
                weekendStyle: TextStyle(color: _accentColor, fontWeight: FontWeight.bold),
              ),
              enabledDayPredicate: (day) => !_isDateBooked(day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  if (_isDateBooked(selectedDay)) {
                    _startDate = null;
                    _endDate = null;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deze datum is niet beschikbaar.')),
                    );
                    return;
                  }

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
            const SizedBox(height: 24),

            if (_startDate != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _inputFillColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Geselecteerde periode:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor.withAlpha((255 * 0.9).round()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Van: ${DateFormat('dd/MM/yyyy').format(_startDate!)}',
                      style: const TextStyle(fontSize: 16, color: _accentColor),
                    ),
                    if (_endDate != null)
                      Text(
                        'Tot: ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                        style: const TextStyle(fontSize: 16, color: _accentColor),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _requestRental,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Huurverzoek indienen',
                      style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _accentColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label:',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: valueColor ?? _accentColor,
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