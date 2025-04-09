import 'package:app/strings.dart';
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
// #region variabelen
  double _panelHeightFactor = 0.6;
  final double _minPanelHeightFactor = 0.2;
  final double _maxPanelHeightFactor = 0.90;
  final double _handleHeight = 10.0;
  LatLng? _currentLocation;
  final MapController _mapController = MapController();

// #endregion 

// #region paneel verplaatsen
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
// #endregion 
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

// #region locatie ophalen
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
    } catch (e) {}
  }
// #endregion
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
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
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
 // #region zoekbalk
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

// #endregion
// #region paneel met items
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
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(1.0),
                            child: Center(
                              child: Text(
                                AppStrings.itemNearby,
                                style: TextStyle(
                                  fontSize: 14,
                                  color:  Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // TODO: item lijst hier zetten
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
// #endregion
        ],
      ),
    );
  }
}
