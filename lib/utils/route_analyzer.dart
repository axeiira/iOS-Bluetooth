import 'dart:math';
import 'package:latlong2/latlong.dart';

class RouteAnalysisResult {
  final double totalDistanceKm;
  final Duration totalDuration;
  final int taggedEventsCount;
  final double averageSpeedKmh;

  RouteAnalysisResult({
    required this.totalDistanceKm,
    required this.totalDuration,
    required this.taggedEventsCount,
    required this.averageSpeedKmh,
  });
}

class RouteAnalyzer {
  static RouteAnalysisResult analyze(List<Map<String, dynamic>> records) {
    if (records.length < 2) {
      return RouteAnalysisResult(
        totalDistanceKm: 0,
        totalDuration: Duration.zero,
        taggedEventsCount: 0,
        averageSpeedKmh: 0,
      );
    }

    records.sort((a, b) => (a['createdAt'] as String).compareTo(b['createdAt'] as String));

    final startTime = DateTime.parse(records.first['createdAt']!);
    final endTime = DateTime.parse(records.last['createdAt']!);
    final totalDuration = endTime.difference(startTime);

    double totalDistanceMeters = 0;

    for (int i = 0; i < records.length - 1; i++) {
      final record1 = records[i];
      final record2 = records[i+1];

      final lat1 = (record1['latitude'] as num).toDouble();
      final lon1 = (record1['longitude'] as num).toDouble();
      final lat2 = (record2['latitude'] as num).toDouble();
      final lon2 = (record2['longitude'] as num).toDouble();

      final point1 = LatLng(lat1, lon1);
      final point2 = LatLng(lat2, lon2);
      
      final distance = _calculateDistance(point1, point2);
      totalDistanceMeters += distance;
    }

    // Gunakan 'eventTagging' dari server
    final taggedEventsCount = records.where((r) => r['eventTagging'] == true).length;

    final totalDistanceKm = totalDistanceMeters / 1000;
    
    final double totalDurationInHours = totalDuration.inSeconds / 3600.0;
    final averageSpeedKmh = (totalDurationInHours > 0)
        ? (totalDistanceKm / totalDurationInHours)
        : 0.0;

    return RouteAnalysisResult(
      totalDistanceKm: totalDistanceKm,
      totalDuration: totalDuration,
      taggedEventsCount: taggedEventsCount,
      averageSpeedKmh: averageSpeedKmh.isFinite ? averageSpeedKmh : 0.0,
    );
  }

  static double _calculateDistance(LatLng latLng1, LatLng latLng2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((latLng2.latitude - latLng1.latitude) * p) / 2 +
        cos(latLng1.latitude * p) *
            cos(latLng2.latitude * p) *
            (1 - cos((latLng2.longitude - latLng1.longitude) * p)) /
            2;
    return 12742 * asin(sqrt(a)) * 1000;
  }
}
