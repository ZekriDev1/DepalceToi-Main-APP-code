import 'package:supabase_flutter/supabase_flutter.dart';

class LocationService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> updateLocation(String userId, double lat, double lng) async {
    await _client.from('locations').upsert({
      'user_id': userId,
      'lat': lat,
      'lng': lng,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Stream<Map<String, dynamic>?> subscribeToUserLocation(String userId) {
    return _client
        .from('locations')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .map((rows) => rows.isNotEmpty ? rows.first as Map<String, dynamic> : null);
  }
} 