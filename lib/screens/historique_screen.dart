import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ride_request.dart';
import '../services/ride_request_service.dart';
import '../services/user_service.dart';

class HistoriqueScreen extends StatefulWidget {
  const HistoriqueScreen({super.key});

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  final RideRequestService _rideRequestService = RideRequestService();
  final UserService _userService = UserService();
  List<RideRequest> _rides = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _userId = user.id;
    final response = await Supabase.instance.client
        .from('ride_requests')
        .select()
        .or('rider_id.eq.$_userId,driver_id.eq.$_userId')
        .order('created_at', ascending: false);
    setState(() {
      _rides = (response as List).map((json) => RideRequest.fromJson(json)).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rides.isEmpty
              ? const Center(child: Text('No rides found.'))
              : ListView.builder(
                  itemCount: _rides.length,
                  itemBuilder: (context, index) {
                    final ride = _rides[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Icon(
                          ride.status == 'completed'
                              ? Icons.check_circle
                              : Icons.directions_car,
                          color: ride.status == 'completed' ? Colors.green : Colors.pink,
                        ),
                        title: Text('Fare: ${ride.fare.toStringAsFixed(2)} DH'),
                        subtitle: Text(
                          'From: (${ride.fromLat.toStringAsFixed(3)}, ${ride.fromLng.toStringAsFixed(3)})\n'
                          'To: (${ride.toLat.toStringAsFixed(3)}, ${ride.toLng.toStringAsFixed(3)})\n'
                          'Status: ${ride.status}\n'
                          'Date: ${ride.createdAt.toLocal().toString().split(".")[0]}'
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 