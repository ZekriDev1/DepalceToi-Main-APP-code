import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteService {
  static const String _baseUrl = 'https://router.project-osrm.org/route/v1';

  Future<RouteInfo?> getRoute(LatLng start, LatLng end) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['code'] == 'Ok') {
        final route = data['routes'][0];
        final distance = route['distance']; // in meters
        final duration = route['duration']; // in seconds
        
        // Calculate fare (example: 5 DH base fare + 2 DH per km)
        final fare = 5.0 + (distance / 1000 * 2.0);
        
        // Convert route geometry to points
        final List<dynamic> coordinates = route['geometry']['coordinates'];
        final List<LatLng> points = coordinates
            .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
            .toList();

        return RouteInfo(
          points: points,
          distance: distance,
          duration: duration,
          fare: fare,
        );
      }
    }
    return null;
  }
}

class RouteInfo {
  final List<LatLng> points;
  final double distance;
  final double duration;
  final double fare;

  RouteInfo({
    required this.points,
    required this.distance,
    required this.duration,
    required this.fare,
  });
} 