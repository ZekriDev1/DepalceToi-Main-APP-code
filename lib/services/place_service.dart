import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceSuggestion {
  final String displayName;
  final double lat;
  final double lon;
  final String type;

  PlaceSuggestion({
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.type,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      displayName: json['display_name'] ?? '',
      lat: double.parse(json['lat'] ?? '0'),
      lon: double.parse(json['lon'] ?? '0'),
      type: json['type'] ?? '',
    );
  }
}

class PlaceService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  Future<List<PlaceSuggestion>> getPlaceSuggestions(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/search?format=json&q=$query&limit=5&addressdetails=1',
        ),
        headers: {
          'User-Agent': 'DéplaceToi Riders App',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => PlaceSuggestion.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching place suggestions: $e');
    }

    return [];
  }

  Future<PlaceSuggestion?> getPlaceDetails(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/reverse?format=json&lat=$lat&lon=$lon&addressdetails=1',
        ),
        headers: {
          'User-Agent': 'DéplaceToi Riders App',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return PlaceSuggestion.fromJson(data);
      }
    } catch (e) {
      print('Error fetching place details: $e');
    }

    return null;
  }

  Future<LatLng?> getPlaceCoordinates(String placeId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/lookup?format=json&osm_ids=$placeId'),
      headers: {'User-Agent': 'DéplaceToi Riders App'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        final place = data[0];
        return LatLng(
          double.parse(place['lat']),
          double.parse(place['lon']),
        );
      }
    }
    return null;
  }
} 