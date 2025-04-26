import 'package:app/ItemDetailPage.dart';
import 'package:app/customMarker.dart';
import 'package:app/strings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double _panelHeightFactor = 0.6;
  final double _minPanelHeightFactor = 0.2;
  final double _maxPanelHeightFactor = 0.90;
  final double _handleHeight = 10.0;
  LatLng? _currentLocation;
  final MapController _mapController = MapController();

  final List<MapEntry<Marker, Map<String, dynamic>>> _markerItems = [];
  double _selectedRadius = 5.0;
  final List<double> _radiusOptions = [5.0, 10.0, 15.0, 20.0, double.infinity];

  // void _handleDragUpdate(DragUpdateDetails details) {
  //   setState(() {
  //     _panelHeightFactor -=
  //         details.delta.dy / MediaQuery.of(context).size.height;

  //     if (_panelHeightFactor >
  //         (1.0 - _handleHeight / MediaQuery.of(context).size.height)) {
  //       _panelHeightFactor =
  //           (1.0 - _handleHeight / MediaQuery.of(context).size.height);
  //     }
  //     _panelHeightFactor = _panelHeightFactor.clamp(
  //       _minPanelHeightFactor,
  //       _maxPanelHeightFactor,
  //     );
  //   });
  // }
  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _panelHeightFactor -= details.delta.dy / MediaQuery.of(context).size.height;

      if (_panelHeightFactor > (1.0 - _handleHeight / MediaQuery.of(context).size.height)) {
        _panelHeightFactor = (1.0 - _handleHeight / MediaQuery.of(context).size.height);
      }
      _panelHeightFactor = _panelHeightFactor.clamp(_minPanelHeightFactor, _maxPanelHeightFactor);
    });
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        final adjustedLocation = LatLng(
          _currentLocation!.latitude - 0.15,
          _currentLocation!.longitude,
        );
        _mapController.move(adjustedLocation, 10.0);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.locationError}$e')),
      );
    }
  }

  void _showItemDetails(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailPage(item: item),
      ),
    );
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(
      _mapController.camera.center,
      currentZoom + 1.0,
    );
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(
      _mapController.camera.center,
      currentZoom - 1.0,
    );
  }

  bool _isItemWithinRadius(LatLng itemLocation) {
    if (_currentLocation == null) return false;

    final distance = const Distance().as(
      LengthUnit.Kilometer,
      _currentLocation!,
      itemLocation,
    );

    if (_selectedRadius == double.infinity) return true;

    return distance <= _selectedRadius;
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
    final panelHeight = MediaQuery.of(context).size.height * _panelHeightFactor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation ?? const LatLng(51.509364, -0.128928),
                initialZoom: 10.0,
                minZoom: 5.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.scrollWheelZoom,
                ),
                onTap: (tapPosition, point) {
                  const markerTapRadius = 50.0;

                  for (var markerEntry in _markerItems) {
                    final marker = markerEntry.key;
                    final item = markerEntry.value;
                    final distance = const Distance().as(
                      LengthUnit.Meter,
                      marker.point,
                      point,
                    );
                    if (distance < markerTapRadius) {
                      _showItemDetails(item);
                      break;
                    }
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                  tileProvider: CancellableNetworkTileProvider(),
                ),
                if (_currentLocation != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _currentLocation!,
                        radius: _selectedRadius == double.infinity ? 0 : _selectedRadius * 1000,
                        color: Colors.red.withOpacity(0.3),
                        borderStrokeWidth: 2.0,
                        borderColor: Colors.red,
                        useRadiusInMeter: true,
                      ),
                    ],
                  ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Items')
                      .where('available', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const MarkerLayer(markers: []);
                    }
                    if (snapshot.hasError) {
                      return const MarkerLayer(markers: []);
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const MarkerLayer(markers: []);
                    }

                    _markerItems.clear();
                    List<Marker> markers = snapshot.data!.docs.map((doc) {
                      var item = doc.data() as Map<String, dynamic>;
                      var location = item['location'] as GeoPoint?;
                      if (location == null) return null;
                      final itemLatLng = LatLng(location.latitude, location.longitude);
                      if (!_isItemWithinRadius(itemLatLng)) return null;
                      final marker = Marker(
                        width: 40,
                        height: 40,
                        point: itemLatLng,
                        child: CustomMarker(
                          point: itemLatLng,
                          item: item,
                          onTap: () => _showItemDetails(item),
                        ),
                      );
                      _markerItems.add(MapEntry(marker, item));
                      return marker;
                    }).whereType<Marker>().toList();

                    return MarkerLayer(
                      markers: [
                        if (_currentLocation != null)
                          Marker(
                            width: 40,
                            height: 40,
                            point: _currentLocation!,
                            child: const Icon(
                              Icons.location_pin,
                              size: 40,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ...markers,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            top: 100,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  onPressed: _zoomIn,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.black),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _zoomOut,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
              ],
            ),
          ),
          Positioned(
            top: 80,
            left: 10,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 4,
                      color: Colors.grey,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButton<double>(
                  value: _selectedRadius,
                  onChanged: (double? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedRadius = newValue;
                      });
                    }
                  },
                  items: _radiusOptions.map((double radius) {
                    return DropdownMenuItem<double>(
                      value: radius,
                      child: Text(
                        radius == double.infinity ? '>20 km' : '${radius.toInt()} km',
                      ),
                    );
                  }).toList(),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: panelHeight,
            child: GestureDetector(
              onVerticalDragUpdate: _handleDragUpdate,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      color: Colors.grey,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
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

                          final filteredDocs = snapshot.data!.docs.where((doc) {
                            var item = doc.data() as Map<String, dynamic>;
                            var location = item['location'] as GeoPoint?;
                            if (location == null) return false;
                            final itemLatLng = LatLng(location.latitude, location.longitude);
                            return _isItemWithinRadius(itemLatLng);
                          }).toList();

                          if (filteredDocs.isEmpty) {
                            return const Center(child: Text('Geen items binnen deze straal'));
                          }

                          return ListView.builder(
                            physics: const ClampingScrollPhysics(),
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, index) {
                              var item = filteredDocs[index].data() as Map<String, dynamic>;
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}