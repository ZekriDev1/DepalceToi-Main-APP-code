import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'Male'; // Default gender
  final List<String> _genders = ['Male', 'Female', 'Other'];
  final _formKey = GlobalKey<FormState>();
  UserProfile? _userProfile;
  bool _isLoading = true;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final userService = UserService();
        final profile = await userService.getUserProfile(user.id);
        setState(() {
          _userProfile = profile;
          _nameController.text = profile?.name ?? '';
          _ageController.text = profile?.birthDate != null ? (DateTime.now().difference(profile!.birthDate).inDays ~/ 365).toString() : '';
          _selectedGender = profile?.gender ?? 'Male';
          _profileImageUrl = profile?.profileImageUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading profile')),
      );
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final userService = UserService();
        final profile = await userService.getUserProfile(user.id);
        
        if (profile == null) {
          // Create a new profile if it doesn't exist
          await userService.createUserProfile(
            userId: user.id,
            email: user.email ?? '',
            name: _nameController.text.trim(),
            birthDate: DateTime.now().subtract(Duration(days: int.parse(_ageController.text) * 365)),
            gender: _selectedGender,
          );
        }

        // Update the profile
        final updatedProfile = await userService.updateUserProfile(
          userId: user.id,
          name: _nameController.text.trim(),
          gender: _selectedGender,
          profileImageUrl: _profileImageUrl,
        );

        if (mounted) {
          setState(() {
            _userProfile = updatedProfile;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _isLoading = true);

        try {
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            // Read image bytes
            final bytes = await image.readAsBytes();
            
            // Create a unique file name
            final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            
            // Upload to Supabase Storage
            await Supabase.instance.client.storage
                .from('profile-images')
                .uploadBinary(
                  fileName,
                  bytes,
                  fileOptions: const FileOptions(
                    cacheControl: '3600',
                    upsert: true,
                  ),
                );

            // Get the public URL
            final imageUrl = Supabase.instance.client.storage
                .from('profile-images')
                .getPublicUrl(fileName);

            setState(() => _profileImageUrl = imageUrl);

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile image updated successfully')),
              );
            }
          }
        } catch (e) {
          print('Error uploading image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error uploading image: $e')),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(languageService.translate('settings')),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_userProfile != null && (_userProfile!.name == null || _userProfile!.gender == null))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.pink[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.pink[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.pink[700]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Please complete your profile information',
                          style: TextStyle(color: Colors.pink),
                        ),
                      ),
                    ],
                  ),
                ),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: _userProfile?.profileImageUrl != null
                          ? NetworkImage(_userProfile!.profileImageUrl!)
                          : null,
                      child: _userProfile?.profileImageUrl == null
                          ? const Icon(Icons.person, size: 60)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.pink,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: languageService.translate('name'),
                              prefixIcon: const Icon(Icons.person, color: Colors.pink),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.pink),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return languageService.translate('please_enter_name');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: InputDecoration(
                              labelText: languageService.translate('gender'),
                              prefixIcon: const Icon(Icons.people, color: Colors.pink),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.pink),
                              ),
                            ),
                            items: [
                              DropdownMenuItem(value: 'male', child: Text(languageService.translate('male'))),
                              DropdownMenuItem(value: 'female', child: Text(languageService.translate('female'))),
                              DropdownMenuItem(value: 'other', child: Text(languageService.translate('other'))),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedGender = value;
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return languageService.translate('please_select_gender');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _ageController,
                            decoration: InputDecoration(
                              labelText: languageService.translate('age'),
                              labelStyle: TextStyle(color: Colors.grey[600]),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(Icons.calendar_today, color: Colors.pink),
                              suffixText: languageService.translate('years'),
                              suffixStyle: TextStyle(color: Colors.grey[600]),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return languageService.translate('please_enter_age');
                              }
                              final age = int.tryParse(value);
                              if (age == null) {
                                return languageService.translate('enter_valid_number');
                              }
                              if (age < 18 || age > 100) {
                                return languageService.translate('age_range');
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                languageService.translate('update_profile'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Language Settings Section
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        languageService.translate('language_settings'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      title: Row(
                        children: [
                          const Text('🇺🇸 '),
                          const SizedBox(width: 8),
                          Text(languageService.translate('language') == 'اللغة' ? 'English' : 'English'),
                        ],
                      ),
                      value: 'en',
                      groupValue: languageService.currentLanguage,
                      onChanged: (value) {
                        if (value != null) {
                          languageService.setLanguage(value);
                        }
                      },
                    ),
                    RadioListTile<String>(
                      title: Row(
                        children: [
                          const Text('🇫🇷 '),
                          const SizedBox(width: 8),
                          Text(languageService.translate('language') == 'اللغة' ? 'Français' : 'Français'),
                        ],
                      ),
                      value: 'fr',
                      groupValue: languageService.currentLanguage,
                      onChanged: (value) {
                        if (value != null) {
                          languageService.setLanguage(value);
                        }
                      },
                    ),
                    RadioListTile<String>(
                      title: Row(
                        children: [
                          const Text('🇸🇦 '),
                          const SizedBox(width: 8),
                          Text(languageService.translate('language') == 'اللغة' ? 'العربية' : 'العربية'),
                        ],
                      ),
                      value: 'ar',
                      groupValue: languageService.currentLanguage,
                      onChanged: (value) {
                        if (value != null) {
                          languageService.setLanguage(value);
                        }
                      },
                    ),
                  ],
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
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }
} 