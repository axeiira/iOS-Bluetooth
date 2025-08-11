import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/route_analyzer.dart';
import '../utils/map_tile_provider.dart';

class MapViewPage extends StatefulWidget {
  final List<Map<String, dynamic>> records;

  const MapViewPage({super.key, required this.records});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  final MapController _mapController = MapController();
  RouteAnalysisResult? _analysisResult;

  @override
  void initState() {
    super.initState();
    if (widget.records.isNotEmpty) {
      setState(() {
        _analysisResult = RouteAnalyzer.analyze(widget.records);
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final List<LatLng> points = widget.records.map((record) {
      final lat = (record['latitude'] as num).toDouble();
      final lon = (record['longitude'] as num).toDouble();
      return LatLng(lat, lon);
    }).toList();

    final LatLng? startPoint = points.isNotEmpty ? points.first : null;
    final LatLng? endPoint = points.isNotEmpty ? points.last : null;
    final LatLngBounds? bounds = points.isNotEmpty ? LatLngBounds.fromPoints(points) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: startPoint ?? const LatLng(-6.2088, 106.8456),
              initialZoom: 15.0,
              onMapReady: () {
                if (bounds != null) {
                  _mapController.fitCamera(
                    CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.fromLTRB(50, 50, 50, 200),
                    ),
                  );
                }
              }
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.people_mobility',
                tileProvider: CustomCachedTileProvider(),
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
                markers: widget.records
                    .where((record) => record['eventTagging'] == true)
                    .map((record) {
                  final lat = (record['latitude'] as num).toDouble();
                  final lon = (record['longitude'] as num).toDouble();
                  return Marker(
                    point: LatLng(lat, lon),
                    width: 24, height: 24,
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
              MarkerLayer(
                markers: [
                  if (startPoint != null)
                    Marker(
                      point: startPoint, width: 24, height: 24,
                      child: Tooltip(
                        message: "Start Point",
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, color: Colors.green,
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
                      point: endPoint, width: 24, height: 24,
                      child: Tooltip(
                        message: "End Point",
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, color: Colors.red,
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
          if (_analysisResult != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildStatisticsCard(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Route Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.route_rounded, "${_analysisResult!.totalDistanceKm.toStringAsFixed(2)} km", "Distance"),
                _buildStatItem(Icons.timer_rounded, _formatDuration(_analysisResult!.totalDuration), "Duration"),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.push_pin_rounded, _analysisResult!.taggedEventsCount.toString(), "Tagged Events"),
                _buildStatItem(Icons.speed_rounded, "${_analysisResult!.averageSpeedKmh.toStringAsFixed(1)} km/h", "Avg. Speed"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }
}
