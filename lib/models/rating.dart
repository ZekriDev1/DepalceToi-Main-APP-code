class Rating {
  final String id;
  final String rideRequestId;
  final String fromUserId;
  final String toUserId;
  final int stars;
  final String? comment;
  final DateTime createdAt;

  Rating({
    required this.id,
    required this.rideRequestId,
    required this.fromUserId,
    required this.toUserId,
    required this.stars,
    this.comment,
    required this.createdAt,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id'],
      rideRequestId: json['ride_request_id'],
      fromUserId: json['from_user_id'],
      toUserId: json['to_user_id'],
      stars: json['stars'],
      comment: json['comment'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ride_request_id': rideRequestId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'stars': stars,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }
} 