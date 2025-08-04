import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class MapViewPage extends StatelessWidget {
  final List<Map<String, dynamic>> records;

  const MapViewPage({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final MapController mapController = MapController();
    
    List<LatLng> points = records.map((record) {
      return LatLng(record['latitude'] as double, record['longitude'] as double);
    }).toList();

    LatLng? startPoint = points.isNotEmpty ? points.first : null;
    LatLng? endPoint = points.isNotEmpty ? points.last : null;
    LatLngBounds? bounds = points.isNotEmpty ? LatLngBounds.fromPoints(points) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: startPoint ?? const LatLng(-6.2088, 106.8456),
          initialZoom: 15.0,
          onMapReady: () {
            if (bounds != null) {
              mapController.fitCamera(
                CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(50.0),
                ),
              );
            }
          }
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.cek',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 4.0,
                color: Colors.blue.shade700,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              if (startPoint != null)
                Marker(
                  point: startPoint,
                  width: 80,
                  height: 80,
                  child: const Tooltip(
                    message: "Start Point",
                    child: Icon(Icons.location_on, color: Colors.green, size: 40),
                  ),
                ),
              if (endPoint != null)
                Marker(
                  point: endPoint,
                  width: 80,
                  height: 80,
                  child: const Tooltip(
                    message: "End Point",
                    child: Icon(Icons.flag_rounded, color: Colors.red, size: 40),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}