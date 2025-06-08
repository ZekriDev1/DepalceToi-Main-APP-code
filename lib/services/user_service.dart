import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../models/user_public_profile.dart';
import 'package:flutter/material.dart';

class UserService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<UserProfile> createUserProfile({
    required String userId,
    required String email,
    String? phone,
    required String name,
    required DateTime birthDate,
    required String gender,
    String role = 'rider',
    bool isDriver = false,
  }) async {
    final now = DateTime.now().toIso8601String();
    
    final data = {
      'id': userId,
      'email': email,
      'phone': phone,
      'name': name,
      'birth_date': birthDate.toIso8601String(),
      'gender': gender,
      'created_at': now,
      'updated_at': now,
      'role': role,
      'is_driver': isDriver,
    };

    final response = await _client
        .from('user_profiles')
        .insert(data)
        .select()
        .single();

    return UserProfile.fromJson(response);
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<UserProfile> updateUserProfile({
    required String userId,
    String? name,
    String? gender,
    String? profileImageUrl,
    String? role,
    bool? isDriver,
  }) async {
    final updates = {
      if (name != null) 'name': name,
      if (gender != null) 'gender': gender,
      if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
      if (role != null) 'role': role,
      if (isDriver != null) 'is_driver': isDriver,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final response = await _client
          .from('user_profiles')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();
      
      if (response == null) {
        throw Exception('Failed to update profile');
      }
      
      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error updating profile: $e');
      throw Exception('Error updating profile: $e');
    }
  }

  Future<void> deleteUserProfile(String userId) async {
    await _client
        .from('user_profiles')
        .delete()
        .eq('id', userId);
  }

  Future<bool> safeUpdateUserProfile({
    required String userId,
    String? name,
    String? gender,
    String? profileImageUrl,
    String? role,
    bool? isDriver,
  }) async {
    final updates = <String, dynamic>{
      if (name != null) 'name': name,
      if (gender != null) 'gender': gender,
      if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
      if (role != null) 'role': role,
      if (isDriver != null) 'is_driver': isDriver,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (updates.length == 1) return true; // Only updated_at, nothing to update

    try {
      final response = await _client
          .from('user_profiles')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      if (response is Map && (name == null || response['name'] == name)) {
        return true;
      }
      return false;
    } catch (e) {
      print('Profile update error: $e');
      return false;
    }
  }

  Future<void> upsertUserPublicProfile({
    required String userId,
    required String name,
    String? profileImageUrl,
  }) async {
    await _client.from('user_public_profiles').upsert({
      'user_id': userId,
      'name': name,
      'profile_image_url': profileImageUrl,
    });
  }

  Future<UserPublicProfile?> getUserPublicProfile(String userId) async {
    try {
      final response = await _client
          .from('user_public_profiles')
          .select()
          .eq('user_id', userId)
          .single();
      return UserPublicProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<UserPublicProfile>> getAllDrivers() async {
    final response = await _client
        .from('user_profiles')
        .select('id, is_driver')
        .eq('is_driver', true);
    final driverIds = (response as List).map((e) => e['id'] as String).toList();
    if (driverIds.isEmpty) return [];
    final publicProfiles = await _client
        .from('user_public_profiles')
        .select()
        .inFilter('user_id', driverIds);
    return (publicProfiles as List)
        .map((json) => UserPublicProfile.fromJson(json))
        .toList();
  }

  bool isProfileComplete(UserProfile? profile) {
    if (profile == null) return false;
    
    return profile.name.isNotEmpty && 
           profile.gender.isNotEmpty && 
           profile.birthDate != null;
  }

  Future<bool> checkAndRedirectToSettings(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    final profile = await getUserProfile(user.id);
    if (!isProfileComplete(profile)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please complete your profile information'),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pushNamed(context, '/settings');
      }
      return true;
    }
    return false;
  }
} 