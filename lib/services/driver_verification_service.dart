import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class DriverVerificationService {
  final supabase = Supabase.instance.client;
  static const String bucketName = 'verifications';

  Future<String> uploadVerificationDocument(XFile file, String userId) async {
    try {
      // Create a unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExt = file.path.split('.').last;
      final fileName = '${userId}_${timestamp}.$fileExt';

      // Read file bytes
      final bytes = await file.readAsBytes();
      
      print('Uploading file: $fileName');
      print('File size: ${bytes.length} bytes');

      // Upload file
      final response = await supabase.storage
          .from(bucketName)
          .uploadBinary(fileName, bytes);

      if (response.isEmpty) {
        throw Exception('Failed to upload file');
      }

      // Get the public URL
      final fileUrl = supabase.storage
          .from(bucketName)
          .getPublicUrl(fileName);

      print('File uploaded successfully: $fileUrl');
      return fileUrl;
    } catch (e) {
      print('Error uploading verification document: $e');
      if (e is StorageException) {
        print('Storage error details: ${e.message}');
        print('Status code: ${e.statusCode}');
        print('Error: ${e.error}');
      }
      rethrow;
    }
  }

  Future<void> submitVerification({
    required String userId,
    required String idNumber,
    required String licenseNumber,
    required String idCardUrl,
    required String licenseUrl,
  }) async {
    try {
      print('Submitting verification for user: $userId');
      print('ID Card URL: $idCardUrl');
      print('License URL: $licenseUrl');

      await supabase.from('driver_verifications').insert({
        'user_id': userId,
        'id_number': idNumber,
        'license_number': licenseNumber,
        'id_card_url': idCardUrl,
        'license_url': licenseUrl,
        'status': 'pending',
      });

      print('Verification submitted successfully');
    } catch (e) {
      print('Error submitting verification: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getVerificationStatus(String userId) async {
    try {
      final response = await supabase
          .from('driver_verifications')
          .select()
          .eq('user_id', userId)
          .single();
      return response;
    } catch (e) {
      print('Error getting verification status: $e');
      return null;
    }
  }

  Future<void> updateVerificationStatus({
    required String userId,
    required String status, // 'pending', 'approved', or 'rejected'
    String? rejectionReason,
  }) async {
    try {
      print('Updating verification status for user: $userId');
      print('New status: $status');
      if (rejectionReason != null) {
        print('Rejection reason: $rejectionReason');
      }

      final updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (rejectionReason != null) {
        updateData['rejection_reason'] = rejectionReason;
      }

      await supabase
          .from('driver_verifications')
          .update(updateData)
          .eq('user_id', userId);

      print('Verification status updated successfully');
    } catch (e) {
      print('Error updating verification status: $e');
      rethrow;
    }
  }

  // Method to get all pending verifications (for admin)
  Future<List<Map<String, dynamic>>> getPendingVerifications() async {
    try {
      final response = await supabase
          .from('driver_verifications')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting pending verifications: $e');
      return [];
    }
  }

  // Method to get all verifications (for admin)
  Future<List<Map<String, dynamic>>> getAllVerifications() async {
    try {
      final response = await supabase
          .from('driver_verifications')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting all verifications: $e');
      return [];
    }
  }
} 