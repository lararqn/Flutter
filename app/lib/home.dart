import 'package:app/strings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';

// ItemDetailPage
class ItemDetailPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const ItemDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item['title'] ?? 'Geen titel'),
        backgroundColor: Colors.blueGrey,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item['imageUrls'] != null && item['imageUrls'].isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: item['imageUrls'].length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Image.network(
                        item['imageUrls'][index],
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
              item['title'] ?? 'Geen titel',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Beschrijving: ${item['description'] ?? 'Geen beschrijving'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Categorie: ${item['category'] ?? 'Onbekend'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Optie: ${item['rentOption'] ?? 'Te leen'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (item['rentOption'] == 'Te huur') ...[
              Text(
                'Prijs per dag: €${item['pricePerDay']?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Extra dag: €${item['extraDayPrice']?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CustomMarker extends StatefulWidget {
  final LatLng point;
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const CustomMarker({
    super.key,
    required this.point,
    required this.item,
    required this.onTap,
  });

  @override
  CustomMarkerState createState() => CustomMarkerState();
}

class CustomMarkerState extends State<CustomMarker> {
  bool _isTapped = false;

  void _handleTap() {
    setState(() {
      _isTapped = true;
    });
    widget.onTap();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isTapped = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Icon(
        Icons.location_pin,
        size: 40,
        color: _isTapped ? Colors.orange : Colors.red,
      ),
    );
  }
}

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

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _panelHeightFactor -=
          details.delta.dy / MediaQuery.of(context).size.height;

      if (_panelHeightFactor >
          (1.0 - _handleHeight / MediaQuery.of(context).size.height)) {
        _panelHeightFactor =
            (1.0 - _handleHeight / MediaQuery.of(context).size.height);
      }
      _panelHeightFactor = _panelHeightFactor.clamp(
        _minPanelHeightFactor,
        _maxPanelHeightFactor,
      );
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

  @override
  Widget build(BuildContext context) {
    final panelHeight = MediaQuery.of(context).size.height * _panelHeightFactor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation ?? LatLng(51.509364, -0.128928),
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
                      final marker = Marker(
                        width: 40,
                        height: 40,
                        point: LatLng(location.latitude, location.longitude),
                        child: CustomMarker(
                          point: LatLng(location.latitude, location.longitude),
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
            top: 30,
            left: 10,
            right: 10,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: AppStrings.searchPlaceholder,
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    contentPadding: EdgeInsets.symmetric(vertical: 15),
                  ),
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
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return const Center(
                                child: Text('Fout bij ophalen items'));
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                                child: Text('Geen items gevonden'));
                          }

                          return ListView.builder(
                            physics: const ClampingScrollPhysics(),
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              var item = snapshot.data!.docs[index].data()
                                  as Map<String, dynamic>;
                              return ListTile(
                                leading: item['imageUrls'] != null &&
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