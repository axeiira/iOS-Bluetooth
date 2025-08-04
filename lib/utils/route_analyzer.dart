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
  // Fungsi utama untuk menganalisis data rute
  static RouteAnalysisResult analyze(List<Map<String, dynamic>> records) {
    if (records.length < 2) {
      return RouteAnalysisResult(
        totalDistanceKm: 0,
        totalDuration: Duration.zero,
        taggedEventsCount: 0,
        averageSpeedKmh: 0,
      );
    }

    // Urutkan records berdasarkan timestamp
    records.sort((a, b) => (a['timestamp'] as String).compareTo(b['timestamp'] as String));

    final startTime = DateTime.parse(records.first['timestamp']!);
    final endTime = DateTime.parse(records.last['timestamp']!);
    final totalDuration = endTime.difference(startTime);

    double totalDistanceMeters = 0;

    for (int i = 0; i < records.length - 1; i++) {
      final record1 = records[i];
      final record2 = records[i+1];

      final point1 = LatLng(record1['latitude'] as double, record1['longitude'] as double);
      final point2 = LatLng(record2['latitude'] as double, record2['longitude'] as double);
      
      final distance = _calculateDistance(point1, point2);
      totalDistanceMeters += distance;
    }

    // Hitung jumlah tag
    final taggedEventsCount = records.where((r) => r['tag_button'] == 1).length;

    final totalDistanceKm = totalDistanceMeters / 1000;
    
    // hitung avg speed (km/h)
    final averageSpeedKmh = (totalDuration.inSeconds > 0)
        ? (totalDistanceKm / (totalDuration.inHours + (totalDuration.inMinutes % 60) / 60))
        : 0.0;

    return RouteAnalysisResult(
      totalDistanceKm: totalDistanceKm,
      totalDuration: totalDuration,
      taggedEventsCount: taggedEventsCount,
      averageSpeedKmh: averageSpeedKmh.isNaN ? 0.0 : averageSpeedKmh,
    );
  }

  // Fungsi untuk menghitung jarak antara dua koordinat (Haversine formula)
  static double _calculateDistance(LatLng latLng1, LatLng latLng2) {
    const p = 0.017453292519943295; // Pi / 180
    final a = 0.5 -
        cos((latLng2.latitude - latLng1.latitude) * p) / 2 +
        cos(latLng1.latitude * p) *
            cos(latLng2.latitude * p) *
            (1 - cos((latLng2.longitude - latLng1.longitude) * p)) /
            2;
    return 12742 * asin(sqrt(a)) * 1000;
  }
}
