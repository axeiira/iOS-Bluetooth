import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapViewPage extends StatefulWidget {
  final List<Map<String, dynamic>> records;

  const MapViewPage({super.key, required this.records});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final List<LatLng> _points = [];
  LatLngBounds? _bounds;

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
    
    _bounds = LatLngBounds.fromPoints(_points);

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
      body: _points.isEmpty
          ? const Center(child: Text("No GPS data to display."))
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _points.first, // posisi awal
                initialZoom: 14.0,
                onMapReady: () {
                  if (_bounds != null) {
                    _mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: _bounds!,
                        padding: const EdgeInsets.all(120.0),
                      ),
                    );
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileProvider: NetworkTileProvider(
                    headers: {
                      'User-Agent': 'com.example.cek',
                    },
                  ),
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _points,
                      color: Colors.blue,
                      strokeWidth: 5,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _points.first,
                      child: const Tooltip(
                        message: "Start Point",
                        child: Icon(Icons.location_on, size: 40.0, color: Colors.green),
                      )
                    ),
                    Marker(
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