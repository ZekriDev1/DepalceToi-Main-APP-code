import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/rating.dart';

class RatingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> submitRating({
    required String rideId,
    required String ratedUserId,
    required String raterId,
    required double stars,
    String? comment,
  }) async {
    try {
      await _supabase.from('ratings').insert({
        'ride_id': rideId,
        'rated_user_id': ratedUserId,
        'rater_id': raterId,
        'stars': stars,
        'comment': comment,
      });
    } catch (e) {
      print('Error submitting rating: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserRatings(String userId) async {
    try {
      final response = await _supabase
          .from('ratings')
          .select()
          .eq('rated_user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting user ratings: $e');
      rethrow;
    }
  }

  Future<double> getUserAverageRating(String userId) async {
    try {
      final response = await _supabase
          .from('ratings')
          .select('stars')
          .eq('rated_user_id', userId);
      
      if (response.isEmpty) return 0.0;
      
      final ratings = List<Map<String, dynamic>>.from(response);
      final total = ratings.fold<double>(
        0,
        (sum, rating) => sum + (rating['stars'] as num).toDouble(),
      );
      return total / ratings.length;
    } catch (e) {
      print('Error getting average rating: $e');
      return 0.0;
    }
  }

  Future<List<Rating>> getRideRequestRatings(String rideRequestId) async {
    final response = await _supabase
        .from('ratings')
        .select()
        .eq('ride_request_id', rideRequestId);
    
    return (response as List).map((json) => Rating.fromJson(json)).toList();
  }
} 