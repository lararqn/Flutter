import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

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
    // Reset de kleur na een korte animatie
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