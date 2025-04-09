import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double _panelHeightFactor = 0.6;
  final double _minPanelHeightFactor = 0.2;
  final double _maxPanelHeightFactor = 0.95;
  final double _handleHeight = 15.0;

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
  Widget build(BuildContext context) {
    final panelHeight = MediaQuery.of(context).size.height * _panelHeightFactor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(51.509364, -0.128928),
                initialZoom: 10.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                  tileProvider: CancellableNetworkTileProvider(),
                ),
              ],
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
                      child: ListView(
                        physics: const ClampingScrollPhysics(),
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Items in jouw buurt',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
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