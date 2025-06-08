class UserPublicProfile {
  final String userId;
  final String name;
  final String? profileImageUrl;

  UserPublicProfile({
    required this.userId,
    required this.name,
    this.profileImageUrl,
  });

  factory UserPublicProfile.fromJson(Map<String, dynamic> json) {
    return UserPublicProfile(
      userId: json['user_id'],
      name: json['name'],
      profileImageUrl: json['profile_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'profile_image_url': profileImageUrl,
    };
  }
} 