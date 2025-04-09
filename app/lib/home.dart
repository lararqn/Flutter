import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  //paneel variabelen
  double _panelHeightFactor = 0.6;
  final double _minPanelHeightFactor = 0.2;
  final double _maxPanelHeightFactor = 0.95;
  final double _handleHeight = 15.0;

  //locatie variabelen
  LatLng? _currentLocation; 
  final MapController _mapController = MapController();

  //paneel drag functie
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
  //huidige locatie ophalen
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
          _currentLocation!.latitude - 0.25,
          _currentLocation!.longitude,
        );
        _mapController.move(adjustedLocation, 10.0);
      });
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final panelHeight = MediaQuery.of(context).size.height * _panelHeightFactor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
        //fluttermap     
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation ?? LatLng(51.509364, -0.128928),
                initialZoom: 10.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                  tileProvider: CancellableNetworkTileProvider(),
                ),
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
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
                    ],
                  ),
              ],
            ),
          ),
           //paneel met items
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
                      child: ListView(
                        physics: const ClampingScrollPhysics(),
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Items in jouw buurt',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            //hier komt inhoud van verhuurde item lijst
                          ),
                        ],
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
