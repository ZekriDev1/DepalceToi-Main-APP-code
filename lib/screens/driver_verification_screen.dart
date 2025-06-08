import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/user_service.dart';
import 'dart:io';

class DriverVerificationScreen extends StatefulWidget {
  final UserProfile userProfile;

  const DriverVerificationScreen({
    super.key,
    required this.userProfile,
  });

  @override
  State<DriverVerificationScreen> createState() => _DriverVerificationScreenState();
}

class _DriverVerificationScreenState extends State<DriverVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idNumberController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  File? _idCardImage;
  File? _licenseImage;
  bool _isLoading = false;
  String? _verificationStatus;
  String? _rejectionReason;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('driver_verifications')
          .select()
          .eq('user_id', widget.userProfile.id)
          .single();
      
      if (response != null) {
        setState(() {
          _verificationStatus = response['status'];
          _rejectionReason = response['rejection_reason'];
          _idNumberController.text = response['id_number'] ?? '';
          _licenseNumberController.text = response['license_number'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading verification status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(bool isIdCard) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        if (isIdCard) {
          _idCardImage = File(image.path);
        } else {
          _licenseImage = File(image.path);
        }
      });
    }
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idCardImage == null || _licenseImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both ID card and license images')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload ID card image
      final idCardPath = 'driver_verifications/${widget.userProfile.id}/id_card.jpg';
      await Supabase.instance.client.storage
          .from('verifications')
          .upload(idCardPath, _idCardImage!);

      // Upload license image
      final licensePath = 'driver_verifications/${widget.userProfile.id}/license.jpg';
      await Supabase.instance.client.storage
          .from('verifications')
          .upload(licensePath, _licenseImage!);

      // Get the public URLs for the uploaded images
      final idCardUrl = Supabase.instance.client.storage
          .from('verifications')
          .getPublicUrl(idCardPath);
      
      final licenseUrl = Supabase.instance.client.storage
          .from('verifications')
          .getPublicUrl(licensePath);

      // Save verification data
      await Supabase.instance.client.from('driver_verifications').upsert({
        'user_id': widget.userProfile.id,
        'id_number': _idNumberController.text,
        'license_number': _licenseNumberController.text,
        'id_card_url': idCardUrl,
        'license_url': licenseUrl,
        'status': 'pending',
        'submitted_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification submitted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error submitting verification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting verification: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Verification'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_verificationStatus != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _verificationStatus == 'approved'
                              ? Colors.green[50]
                              : _verificationStatus == 'rejected'
                                  ? Colors.red[50]
                                  : Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _verificationStatus == 'approved'
                                ? Colors.green
                                : _verificationStatus == 'rejected'
                                    ? Colors.red
                                    : Colors.orange,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _verificationStatus == 'approved'
                                  ? Icons.check_circle
                                  : _verificationStatus == 'rejected'
                                      ? Icons.cancel
                                      : Icons.pending,
                              color: _verificationStatus == 'approved'
                                  ? Colors.green
                                  : _verificationStatus == 'rejected'
                                      ? Colors.red
                                      : Colors.orange,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _verificationStatus == 'approved'
                                  ? 'Verified Driver'
                                  : _verificationStatus == 'rejected'
                                      ? 'Verification Rejected'
                                      : 'Verification Pending',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _verificationStatus == 'approved'
                                    ? Colors.green
                                    : _verificationStatus == 'rejected'
                                        ? Colors.red
                                        : Colors.orange,
                              ),
                            ),
                            if (_rejectionReason != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _rejectionReason!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    TextFormField(
                      controller: _idNumberController,
                      decoration: const InputDecoration(
                        labelText: 'ID Card Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your ID card number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _licenseNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Driver\'s License Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your license number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Upload ID Card',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _pickImage(true),
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _idCardImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _idCardImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.upload_file, size: 48),
                                    SizedBox(height: 8),
                                    Text('Tap to upload ID card'),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Upload Driver\'s License',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _pickImage(false),
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _licenseImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _licenseImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.upload_file, size: 48),
                                    SizedBox(height: 8),
                                    Text('Tap to upload license'),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_verificationStatus != 'approved')
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitVerification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _verificationStatus == 'pending'
                              ? 'Update Verification'
                              : 'Submit Verification',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }
} 