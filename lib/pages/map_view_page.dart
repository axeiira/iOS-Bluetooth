import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapViewPage extends StatefulWidget {
  final List<Map<String, dynamic>> records;

  const MapViewPage({super.key, required this.records});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  final List<LatLng> _points = [];
  LatLng? _initialCameraCenter;

  @override
  void initState() {
    super.initState();
    _createRoute();
  }

  void _createRoute() {
    if (widget.records.isEmpty) return;

    for (var record in widget.records) {
      _points.add(LatLng(
        record['latitude'] as double,
        record['longitude'] as double,
      ));
    }
    
    // Atur posisi kamera awal ke titik pertama
    _initialCameraCenter = _points.first;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Route History"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _initialCameraCenter == null
          ? const Center(child: Text("No GPS data to display."))
          : FlutterMap(
              options: MapOptions(
                initialCenter: _initialCameraCenter!,
                initialZoom: 14.0,
              ),
              children: [
                // Layer 1: Tile Peta dari OpenStreetMap
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.cek',
                ),
                // Layer 2: Garis Rute (Polyline)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _points,
                      color: Colors.blue,
                      strokeWidth: 5,
                    ),
                  ],
                ),
                // Layer 3: Titik Awal dan Akhir (Marker)
                MarkerLayer(
                  markers: [
                    // Marker Titik Awal
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: _points.first,
                      child: const Tooltip(
                        message: "Start Point",
                        child: Icon(Icons.location_on, size: 40.0, color: Colors.green),
                      )
                    ),
                    // Marker Titik Akhir
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: _points.last,
                      child: const Tooltip(
                        message: "End Point",
                        child: Icon(Icons.location_on, size: 40.0, color: Colors.red),
                      )
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}