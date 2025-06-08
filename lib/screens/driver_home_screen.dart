import 'package:flutter/material.dart';
import '../models/ride_request.dart';
import '../services/ride_request_service.dart';
import '../services/user_service.dart';
import '../services/location_service.dart';
import '../services/rating_service.dart';
import '../services/language_service.dart';
import '../widgets/rating_bar.dart';
import '../widgets/language_selector.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:geolocator/geolocator.dart';
import '../models/user_profile.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'ratings_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'driver_verification_screen.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key, required this.userProfile, required this.currentPosition});

  final dynamic userProfile;
  final dynamic currentPosition;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final RideRequestService _rideRequestService = RideRequestService();
  final Map<String, String> _riderNames = {};
  List<RideRequest> _pendingRequests = [];
  bool _isLoading = true;
  bool _isOnline = false;
  StreamSubscription? _rideRequestSubscription;
  LocationService _locationService = LocationService();
  Timer? _locationUpdateTimer;
  StreamSubscription? _otherLocationSub;
  gmaps.LatLng? _riderLocation;
  Set<gmaps.Marker> _markers = {};
  Set<gmaps.Polyline> _polylines = {};
  bool _isNavigatingToRider = false;
  gmaps.GoogleMapController? _mapController;
  final String _orsApiKey = '5b3ce3597851110001cf6248c24d8297d85f43c09690ee09a61da10d';
  Set<gmaps.Polyline> _routePolylines = {};
  bool _isNavigating = false;
  gmaps.LatLng? _currentDestination;
  String? _verificationStatus;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final response = await Supabase.instance.client
          .from('driver_verifications')
          .select()
          .eq('user_id', widget.userProfile.id)
          .single();
      
      if (response != null) {
        setState(() {
          _verificationStatus = response['status'];
        });
      }
    } catch (e) {
      print('Error loading verification status: $e');
    }
  }

  void _toggleOnlineStatus(bool value) async {
    if (value && _verificationStatus != 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete driver verification first'),
          action: SnackBarAction(
            label: 'Verify Now',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DriverVerificationScreen(
                    userProfile: widget.userProfile,
                  ),
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    setState(() {
      _isOnline = value;
      if (_isOnline) {
        _setupRealtimeSubscription();
        _fetchPendingRequests();
      } else {
        _rideRequestSubscription?.cancel();
        _otherLocationSub?.cancel();
        _locationUpdateTimer?.cancel();
        setState(() {
          _pendingRequests = [];
          _markers = {};
          _polylines = {};
        });
      }
    });
  }

  Future<void> _fetchPendingRequests() async {
    try {
      final requests = await _rideRequestService.getNearbyPendingRequests(
        widget.currentPosition.latitude,
        widget.currentPosition.longitude,
      );
      setState(() {
        _pendingRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching pending requests: $e');
      setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeSubscription() {
    _rideRequestSubscription?.cancel();
    _rideRequestSubscription = _rideRequestService
        .subscribeToRideRequests()
        .listen((request) async {
      if (request != null) {
        if (request.status == 'pending') {
          // Show new ride request dialog
          if (mounted) {
            _showRideRequestDialog(request);
          }
        } else if (request.status == 'accepted' && request.driverId == widget.userProfile?.id) {
          // Subscribe to rider's location
          _subscribeToRiderLocation(request.riderId);
          
          // Show navigation dialog
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Column(
                  children: [
                    Icon(Icons.directions_car, color: Colors.pink, size: 48),
                    const SizedBox(height: 12),
                    const Text('Start Navigation', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('A rider is waiting for you.'),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _startNavigationToRider(request.riderId);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Start Navigation'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _cancelRide(request.id);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        }
      }
    });
  }

  void _subscribeToRiderLocation(String riderId) {
    _otherLocationSub?.cancel();
    _otherLocationSub = _locationService.subscribeToUserLocation(riderId).listen((data) {
      if (data != null) {
        setState(() {
          _riderLocation = gmaps.LatLng(data['lat'], data['lng']);
          _updateRiderMarker();
        });
      }
    });
  }

  void _updateRiderMarker() {
    if (_riderLocation != null) {
      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'rider_location');
        _markers.add(
          gmaps.Marker(
            markerId: const gmaps.MarkerId('rider_location'),
            position: _riderLocation!,
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueGreen),
            infoWindow: const gmaps.InfoWindow(title: 'Rider Location'),
          ),
        );
      });
    }
  }

  void _startNavigationToRider(String riderId) {
    setState(() {
      _isNavigatingToRider = true;
    });
    // Start updating driver's location
    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isNavigatingToRider) {
        timer.cancel();
        return;
      }
      try {
        Position pos = await Geolocator.getCurrentPosition();
        await _locationService.updateLocation(
          widget.userProfile!.id,
          pos.latitude,
          pos.longitude,
        );
      } catch (e) {
        print('Error updating location: $e');
      }
    });
  }

  Future<void> _cancelRide(String requestId) async {
    try {
      await _rideRequestService.updateRideRequestStatus(requestId, 'cancelled');
      setState(() {
        _isNavigatingToRider = false;
      });
      _otherLocationSub?.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error cancelling ride')),
        );
      }
    }
  }

  Future<void> _acceptRide(String requestId) async {
    try {
      await _rideRequestService.updateRideRequestStatus(requestId, 'accepted', driverId: widget.userProfile?.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride request accepted')),
      );
      
      // Start navigation
      final request = _pendingRequests.firstWhere((r) => r.id == requestId);
      _startNavigation(request);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error accepting ride request')),
      );
    }
  }

  void _shareRideDetails(RideRequest request) async {
    try {
      // Get rider's profile
      final riderProfile = await UserService().getUserProfile(request.riderId);
      
      // Format the share text
      final shareText = '''
🚗 Ride Details:
From: ${request.pickupLocation ?? 'Pickup location'}
To: ${request.destinationLocation ?? 'Destination location'}
Fare: ${request.fare.toStringAsFixed(2)} DH
Status: ${request.status}

👤 Rider Details:
Name: ${riderProfile?.name ?? 'Unknown'}
Email: ${riderProfile?.email ?? 'Unknown'}

Track this ride: https://deplacetoi.com/ride/${request.id}
''';

      // Share the text
      await Share.share(shareText, subject: 'Ride Details');
    } catch (e) {
      print('Error sharing ride details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error sharing ride details')),
        );
      }
    }
  }

  void _showRideRequestDialog(RideRequest request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // User Profile Section
                FutureBuilder<UserProfile?>(
                  future: UserService().getUserProfile(request.riderId),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      final userProfile = snapshot.data!;
                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: userProfile.profileImageUrl != null
                                ? NetworkImage(userProfile.profileImageUrl!)
                                : null,
                            child: userProfile.profileImageUrl == null
                                ? const Icon(Icons.person, size: 40)
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            userProfile.name ?? 'Rider',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.pink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            userProfile.email ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      );
                    }
                    return const CircularProgressIndicator();
                  },
                ),
                const SizedBox(height: 24),
                // Locations Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      // Pickup Location
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.location_on, color: Colors.green[700], size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pickup',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '${request.fromLat.toStringAsFixed(6)}, ${request.fromLng.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Destination Location
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.location_on, color: Colors.red[700], size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Destination',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '${request.toLat.toStringAsFixed(6)}, ${request.toLng.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Fare Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.pink[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Fare:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink,
                        ),
                      ),
                      Text(
                        '${request.fare.toStringAsFixed(2)} DH',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Add Share Button before the Accept/Decline buttons
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _shareRideDetails(request);
                  },
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: const Text('Share Ride Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Accept Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _acceptRide(request.id);
                          // Add markers for pickup and destination
                          setState(() {
                            _markers.add(
                              gmaps.Marker(
                                markerId: const gmaps.MarkerId('pickup'),
                                position: gmaps.LatLng(request.fromLat, request.fromLng),
                                icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueGreen),
                                infoWindow: const gmaps.InfoWindow(title: 'Pickup Location'),
                              ),
                            );
                            _markers.add(
                              gmaps.Marker(
                                markerId: const gmaps.MarkerId('destination'),
                                position: gmaps.LatLng(request.toLat, request.toLng),
                                icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
                                infoWindow: const gmaps.InfoWindow(title: 'Destination'),
                              ),
                            );
                            // Center map on pickup location
                            _mapController?.animateCamera(
                              gmaps.CameraUpdate.newLatLngZoom(
                                gmaps.LatLng(request.fromLat, request.fromLng),
                                15,
                              ),
                            );
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Accept',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Decline Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Decline',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _calculateRoute(gmaps.LatLng start, gmaps.LatLng end) async {
    try {
      final url = 'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$_orsApiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final geometry = data['features'][0]['geometry'];
        if (geometry['type'] == 'LineString') {
          final coords = geometry['coordinates'] as List;
          final points = coords.map<gmaps.LatLng>((c) => gmaps.LatLng(c[1], c[0])).toList();
          
          setState(() {
            _routePolylines.clear();
            _routePolylines.add(
              gmaps.Polyline(
                polylineId: const gmaps.PolylineId('route'),
                points: points,
                color: const Color.fromARGB(255, 255, 0, 106),
                width: 5,
              ),
            );
          });

          // Fit the map to show the entire route
          final bounds = _getBoundsForPoints(points);
          _mapController?.animateCamera(
            gmaps.CameraUpdate.newLatLngBounds(bounds, 50),
          );
        }
      }
    } catch (e) {
      print('Error calculating route: $e');
    }
  }

  gmaps.LatLngBounds _getBoundsForPoints(List<gmaps.LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    for (var point in points) {
      if (minLat == null || point.latitude < minLat) minLat = point.latitude;
      if (maxLat == null || point.latitude > maxLat) maxLat = point.latitude;
      if (minLng == null || point.longitude < minLng) minLng = point.longitude;
      if (maxLng == null || point.longitude > maxLng) maxLng = point.longitude;
    }
    return gmaps.LatLngBounds(
      southwest: gmaps.LatLng(minLat!, minLng!),
      northeast: gmaps.LatLng(maxLat!, maxLng!),
    );
  }

  void _startNavigation(RideRequest request) {
    setState(() {
      _isNavigating = true;
      _currentDestination = gmaps.LatLng(request.toLat, request.toLng);
    });

    // Calculate initial route
    if (widget.currentPosition != null) {
      _calculateRoute(
        gmaps.LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude),
        _currentDestination!,
      );
    }

    // Start periodic route updates
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isNavigating) {
        timer.cancel();
        return;
      }
      if (widget.currentPosition != null && _currentDestination != null) {
        _calculateRoute(
          gmaps.LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude),
          _currentDestination!,
        );
      }
    });
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _currentDestination = null;
      _routePolylines.clear();
    });
  }

  @override
  void dispose() {
    _rideRequestSubscription?.cancel();
    _otherLocationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(languageService.translate('driver_screen')),
            const SizedBox(width: 8),
            FutureBuilder<double>(
              future: RatingService().getUserAverageRating(widget.userProfile.id),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 24,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [
          Row(
            children: [
              Text(
                _isOnline 
                    ? languageService.translate('online')
                    : languageService.translate('offline'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: _isOnline,
                onChanged: _toggleOnlineStatus,
                activeColor: Colors.green,
                inactiveTrackColor: Colors.grey,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RatingsScreen(
                    userProfile: widget.userProfile,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isOnline ? () {
              setState(() => _isLoading = true);
              _setupRealtimeSubscription();
            } : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isOnline) ...[
            gmaps.GoogleMap(
              initialCameraPosition: gmaps.CameraPosition(
                target: widget.currentPosition ?? const gmaps.LatLng(0, 0),
                zoom: 15,
              ),
              markers: _markers,
              polylines: {..._polylines, ..._routePolylines},
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
            if (_isNavigating)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.navigation, color: Colors.pink),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Following route to destination...',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.blue),
                            onPressed: () {
                              final request = _pendingRequests.firstWhere(
                                (r) => r.status == 'accepted' && r.driverId == widget.userProfile?.id,
                              );
                              _shareRideDetails(request);
                            },
                          ),
                          TextButton(
                            onPressed: _stopNavigation,
                            child: const Text('End Navigation'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ] else ...[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    languageService.translate('you_are_offline'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    languageService.translate('toggle_switch'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (_verificationStatus != 'approved') ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DriverVerificationScreen(
                              userProfile: widget.userProfile,
                            ),
                          ),
                        ).then((_) => _loadVerificationStatus());
                      },
                      icon: const Icon(Icons.verified_user),
                      label: Text(languageService.translate('complete_verification')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
} 