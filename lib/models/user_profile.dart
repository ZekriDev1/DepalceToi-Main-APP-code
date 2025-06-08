class UserProfile {
  final String id;
  final String email;
  final String? phone;
  final String name;
  final DateTime birthDate;
  final String gender;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String role;
  final bool isDriver;

  UserProfile({
    required this.id,
    required this.email,
    this.phone,
    required this.name,
    required this.birthDate,
    required this.gender,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.role,
    this.isDriver = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      email: json['email'],
      phone: json['phone'],
      name: json['name'],
      birthDate: DateTime.parse(json['birth_date']),
      gender: json['gender'],
      profileImageUrl: json['profile_image_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      role: json['role'] ?? 'rider',
      isDriver: json['is_driver'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'name': name,
      'birth_date': birthDate.toIso8601String(),
      'gender': gender,
      'profile_image_url': profileImageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'role': role,
      'is_driver': isDriver,
    };
  }
} 