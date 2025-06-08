import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ride_request.dart';

class RideRequestService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> createRideRequest({
    required String riderId,
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required double fare,
    required String pickupAddress,
    required String destinationAddress,
  }) async {
    try {
      print('Validating ride request data...');
      if (riderId.isEmpty) {
        throw Exception('Rider ID is required');
      }
      if (fare <= 0) {
        throw Exception('Fare must be greater than 0');
      }

      print('Inserting ride request into database...');
      final response = await _client.from('ride_requests').insert({
        'rider_id': riderId,
        'from_lat': fromLat,
        'from_lng': fromLng,
        'to_lat': toLat,
        'to_lng': toLng,
        'fare': fare,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      print('Ride request inserted successfully: $response');
    } catch (e) {
      print('Error creating ride request: $e');
      throw Exception('Failed to create ride request: ${e.toString()}');
    }
  }

  Future<List<RideRequest>> getNearbyPendingRequests(double lat, double lng, {double radiusKm = 5}) async {
    // For demo: fetch all pending requests (add geo filtering if needed)
    final response = await _client
        .from('ride_requests')
        .select()
        .eq('status', 'pending');
    return (response as List)
        .map((json) => RideRequest.fromJson(json))
        .toList();
  }

  Future<String?> tryAcceptRideRequest(String requestId, String driverId) async {
    try {
      await _client.from('ride_requests').update({
        'status': 'accepted',
        'driver_id': driverId,
      }).eq('id', requestId);
      return null; // Success
    } catch (e) {
      return e.toString(); // Return error message
    }
  }

  // Subscribe to new ride requests for drivers
  Stream<List<RideRequest>> subscribeToNewRideRequests() {
    return _client
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .map((events) => events.map((json) => RideRequest.fromJson(json)).toList());
  }

  // Subscribe to ride request updates for riders
  Stream<RideRequest?> subscribeToRideRequestUpdates(String requestId) {
    return _client
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .eq('id', requestId)
        .map((events) => events.isNotEmpty ? RideRequest.fromJson(events.first) : null);
  }

  // Get a specific ride request
  Future<RideRequest?> getRideRequest(String requestId) async {
    try {
      final response = await _client
          .from('ride_requests')
          .select()
          .eq('id', requestId)
          .single();
      return RideRequest.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteRideRequest(String requestId) async {
    await _client.from('ride_requests').delete().eq('id', requestId);
  }

  Future<void> markRideCompleted(String requestId) async {
    await _client.from('ride_requests').update({
      'status': 'completed',
    }).eq('id', requestId);
  }

  Future<void> submitRideRating(String requestId, int rating, String? comment) async {
    await _client.from('ride_requests').update({
      'rating': rating,
      'rating_comment': comment,
    }).eq('id', requestId);
  }

  Future<bool> tryAcceptRide(String rideId, String driverId) async {
    final response = await Supabase.instance.client
        .rpc('accept_ride_request', params: {
          '_ride_id': rideId,
          '_driver_id': driverId,
        }).single();
    if (response is Map && response.containsKey('error') && response['error'] != null) {
      throw Exception(response['error']['message']);
    }
    // The function returns a boolean, which will be in the 'data' key
    return response is Map && response.containsKey('data') ? response['data'] == true : false;
  }

  Stream<RideRequest?> subscribeToRideRequests() {
    return _client
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .map((data) {
          if (data.isEmpty) return null;
          return RideRequest.fromJson(data.first);
        });
  }

  Future<void> updateRideRequestStatus(String requestId, String status, {String? driverId}) async {
    final updates = {
      'status': status,
      if (driverId != null) 'driver_id': driverId,
    };
    
    await _client
        .from('ride_requests')
        .update(updates)
        .eq('id', requestId);
  }
} 