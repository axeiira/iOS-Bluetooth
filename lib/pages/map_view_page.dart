import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapViewPage extends StatelessWidget {
  final List<Map<String, dynamic>> records;

  const MapViewPage({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final MapController mapController = MapController();
    
    final List<LatLng> points = records.map((record) {
      return LatLng(record['latitude'] as double, record['longitude'] as double);
    }).toList();

    final LatLng? startPoint = points.isNotEmpty ? points.first : null;
    final LatLng? endPoint = points.isNotEmpty ? points.last : null;
    final LatLngBounds? bounds = points.isNotEmpty ? LatLngBounds.fromPoints(points) : null;

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
            userAgentPackageName: 'com.example.people_mobility',
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
          
          // Layer untuk pin tag
          MarkerLayer(
            markers: records
                .where((record) => record['tag_button'] == 1)
                .map((record) {
              return Marker(
                point: LatLng(
                  record['latitude'] as double,
                  record['longitude'] as double,
                ),
                width: 24,
                height: 24,
                child: Tooltip(
                  message: "Tagged Event",
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade800,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.3), spreadRadius: 2, blurRadius: 5)
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          // Layer untuk titik awal dan akhir
          MarkerLayer(
            markers: [
              if (startPoint != null)
                Marker(
                  point: startPoint,
                  width: 24,
                  height: 24,
                  child: Tooltip(
                    message: "Start Point",
                    // Lingkaran hijau untuk titik awal
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), spreadRadius: 2, blurRadius: 5)
                        ],
                      ),
                    ),
                  ),
                ),
              if (endPoint != null)
                Marker(
                  point: endPoint,
                  width: 24,
                  height: 24,
                  child: Tooltip(
                    message: "End Point",
                    // Lingkaran merah untuk titik akhir
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), spreadRadius: 2, blurRadius: 5)
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}