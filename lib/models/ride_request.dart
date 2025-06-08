class RideRequest {
  final String id;
  final String riderId;
  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;
  final double fare;
  final String status;
  final String? driverId;
  final DateTime createdAt;
  final String? pickupLocation;
  final String? destinationLocation;

  RideRequest({
    required this.id,
    required this.riderId,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    required this.fare,
    required this.status,
    this.driverId,
    required this.createdAt,
    this.pickupLocation,
    this.destinationLocation,
  });

  factory RideRequest.fromJson(Map<String, dynamic> json) {
    return RideRequest(
      id: json['id'],
      riderId: json['rider_id'],
      fromLat: json['from_lat'].toDouble(),
      fromLng: json['from_lng'].toDouble(),
      toLat: json['to_lat'].toDouble(),
      toLng: json['to_lng'].toDouble(),
      fare: json['fare'].toDouble(),
      status: json['status'],
      driverId: json['driver_id'],
      createdAt: DateTime.parse(json['created_at']),
      pickupLocation: json['pickup_location'],
      destinationLocation: json['destination_location'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rider_id': riderId,
      'from_lat': fromLat,
      'from_lng': fromLng,
      'to_lat': toLat,
      'to_lng': toLng,
      'fare': fare,
      'status': status,
      'driver_id': driverId,
      'created_at': createdAt.toIso8601String(),
      'pickup_location': pickupLocation,
      'destination_location': destinationLocation,
    };
  }
} 