import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';
import '../services/place_service.dart';
import '../services/route_service.dart';
import '../models/user_profile.dart';
import '../widgets/rating_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/ride_request_service.dart';
import '../models/ride_request.dart';
import 'driver_home_screen.dart';
import 'package:lottie/lottie.dart';
import 'historique_screen.dart';
import '../services/location_service.dart';
import '../services/rating_service.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../widgets/rating_dialog.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  gmaps.GoogleMapController? _mapController;
  final PlaceService _placeService = PlaceService();
  final RouteService _routeService = RouteService();
  
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  Set<gmaps.Marker> _markers = {};
  Set<gmaps.Polyline> _polylines = {};
  Position? _currentPosition;
  gmaps.LatLng? _destinationLocation;
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isDragging = false;
  bool _showFare = false;
  bool _isExpanded = false;
  final String _apiKey = 'AIzaSyAQbEJrX8nxOLDXr7095V4uKA2715q_jl0';
  final String _orsApiKey = '5b3ce3597851110001cf6248c24d8297d85f43c09690ee09a61da10d';
  gmaps.LatLng? _mapCenter;
  bool _isCameraMoving = false;
  StreamSubscription<Position>? _positionStream;
  gmaps.BitmapDescriptor? _customUserPin;
  bool _useTypingMethod = false;
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;
  double? _lastDistance;
  double? _minFare;
  double? _chosenFare;
  String _role = 'rider';
  final RideRequestService _rideRequestService = RideRequestService();
  List<RideRequest> _pendingRequests = [];
  StreamSubscription? _rideRequestSubscription;
  String? _currentRideRequestId;
  LocationService _locationService = LocationService();
  Timer? _locationUpdateTimer;
  StreamSubscription? _otherLocationSub;
  gmaps.LatLng? _driverLocation;
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _loadUserProfile();
    _loadCustomUserPin();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _startLocationTracking();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    setState(() => _isLoading = true);
    try {
      await _userService.checkAndRedirectToSettings(context);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _initializeMap() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final position = await Geolocator.getCurrentPosition();
        setState(() {
        _currentPosition = position;
          _isLoading = false;
        });

        _addCurrentLocationMarker();

        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          _fromController.text =
              '${place.street}, ${place.locality}, ${place.country}';
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error getting location')),
      );
    }
  }

  Future<void> _loadCustomUserPin() async {
    final pin = await gmaps.BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(16, 16)),
      'assets/images/pin.png',
    );
    setState(() {
      _customUserPin = pin;
    });
  }

  void _startLocationTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      _addCurrentLocationMarker();
      });
    });
  }

  Future<void> _addCurrentLocationMarker() async {
    if (_currentPosition == null) return;
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'current_location');
      _markers.add(
        gmaps.Marker(
          markerId: const gmaps.MarkerId('current_location'),
          position: gmaps.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: _customUserPin ?? gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueBlue),
          infoWindow: const gmaps.InfoWindow(title: 'Your Location'),
        ),
      );
    });
  }

  Future<void> _onMapTap(gmaps.LatLng position) async {
    if (_isDragging) return;

    setState(() {
      _isDragging = true;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        final address = '${place.street}, ${place.locality}, ${place.country}';
        
        setState(() {
          _destinationLocation = position;
          _toController.text = address;
          _markers.add(
            gmaps.Marker(
              markerId: const gmaps.MarkerId('destination'),
              position: position,
              icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
              infoWindow: gmaps.InfoWindow(
                title: 'Destination',
                snippet: address,
              ),
            ),
          );
        });

        if (_currentPosition != null) {
          await _calculateRoute();
        }
      }
    } catch (e) {
      print('Error getting place details: $e');
    } finally {
      setState(() {
        _isDragging = false;
      });
    }
  }

  Future<void> _calculateRoute() async {
    if (_currentPosition == null || _destinationLocation == null) return;
    try {
      final url = 'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$_orsApiKey&start=${_currentPosition!.longitude},${_currentPosition!.latitude}&end=${_destinationLocation!.longitude},${_destinationLocation!.latitude}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final geometry = data['features'][0]['geometry'];
        if (geometry['type'] == 'LineString') {
          final coords = geometry['coordinates'] as List;
          final points = coords.map<gmaps.LatLng>((c) => gmaps.LatLng(c[1], c[0])).toList();
          setState(() {
            _polylines.clear();
            _polylines.add(
              gmaps.Polyline(
                polylineId: const gmaps.PolylineId('route'),
                points: points,
                color: const Color.fromARGB(255, 255, 0, 106),
                width: 5,
              ),
            );
            _showFare = true;
          });
          final bounds = _getBoundsForPoints(points);
          _mapController?.animateCamera(
            gmaps.CameraUpdate.newLatLngBounds(bounds, 50),
          );
        }
        // Get distance in meters
        final distance = data['features'][0]['properties']['segments'][0]['distance'] ?? 0.0;
        setState(() {
          _lastDistance = distance;
        });
        // Calculate minimum fare (e.g., 7 DH base + 2 DH/km)
        final minFare = 7.0 + 2.0 * (distance / 1000.0);
        setState(() {
          _minFare = minFare;
          _chosenFare = minFare;
        });
        
        // Show the fare popup first
        await _showFarePopup();
      } else {
        print('ORS error: ${response.body}');
      }
    } catch (e) {
      print('Error calculating route: $e');
    }
  }

  List<gmaps.LatLng> _decodePolyline(String encoded) {
    List<gmaps.LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(gmaps.LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
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

  Future<void> _loadUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final userService = UserService();
        final profile = await userService.getUserProfile(user.id);
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading profile')),
      );
    }
  }

  Future<void> _switchRole() async {
    if (_userProfile == null) return;
    final newIsDriver = !_userProfile!.isDriver;
    final userService = UserService();
    await userService.updateUserProfile(userId: _userProfile!.id, isDriver: newIsDriver);
    final updated = await userService.getUserProfile(_userProfile!.id);
    if (updated == null) return;
    setState(() {
      _userProfile = updated;
    });
    if (newIsDriver) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DriverHomeScreen(
              userProfile: updated,
              currentPosition: _currentPosition == null
                  ? null
                  : gmaps.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchPendingRequests() async {
    if (_currentPosition == null) return;
    final requests = await _rideRequestService.getNearbyPendingRequests(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
    setState(() {
      _pendingRequests = requests;
    });
  }

  void _showUserMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              CircleAvatar(
                radius: 48,
                backgroundImage: _userProfile?.profileImageUrl != null
                    ? NetworkImage(_userProfile!.profileImageUrl!)
                    : null,
                child: _userProfile?.profileImageUrl == null
                    ? const Icon(Icons.person, size: 48)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                _userProfile?.name != null ? 'Hello, ${_userProfile!.name}!' : 'Hello!',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _userProfile?.email ?? '',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DriverHomeScreen(
                        userProfile: _userProfile,
                        currentPosition: _currentPosition == null
                            ? null
                            : gmaps.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: const Text(
                  'Be a DéplaceToi Driver !',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HistoriqueScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text('Historique', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/settings');
                    },
                    icon: const Icon(Icons.settings, color: Colors.white),
                    label: const Text('Settings', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });

      _addCurrentLocationMarker();

      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        _fromController.text =
            '${place.street}, ${place.locality}, ${place.country}';
      }

      _mapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(gmaps.LatLng(position.latitude, position.longitude), 15),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error getting current location')),
      );
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=$query'
          '&key=$_apiKey'
          '&components=country:ma',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
        setState(() {
            _suggestions = predictions.map((prediction) {
              return {
                'place_id': prediction['place_id'],
                'description': prediction['description'],
                'main_text': prediction['structured_formatting']['main_text'],
                'secondary_text': prediction['structured_formatting']['secondary_text'],
              };
            }).toList();
          });
        } else {
          setState(() {
            _suggestions = [];
          });
        }
      }
    } catch (e) {
      setState(() {
        _suggestions = [];
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _getPlaceDetails(String placeId, bool isFrom) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=geometry,formatted_address'
          '&key=$_apiKey',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];
          final address = result['formatted_address'];
        setState(() {
            _destinationLocation = gmaps.LatLng(lat, lng);
            _toController.text = address;
            _suggestions = [];
            // Add or update the destination marker
            _markers.removeWhere((m) => m.markerId.value == 'destination');
            _markers.add(
              gmaps.Marker(
                markerId: const gmaps.MarkerId('destination'),
                position: gmaps.LatLng(lat, lng),
                icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
                infoWindow: gmaps.InfoWindow(
                  title: 'Destination',
                  snippet: address,
                ),
              ),
            );
          });
          _mapController?.animateCamera(
            gmaps.CameraUpdate.newLatLngZoom(gmaps.LatLng(lat, lng), 15),
          );
        }
      }
    } catch (e) {
      print('Error getting place details: $e');
    }
  }

  Future<void> _showFarePopup() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Set Your Fare',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.pink),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Minimum fare: ${_minFare?.toStringAsFixed(2) ?? '-'} DH',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.pink),
                          onPressed: () {
                            setModalState(() {
                              if (_chosenFare != null && _minFare != null && _chosenFare! > _minFare!) {
                                _chosenFare = (_chosenFare! - 1).clamp(_minFare!, double.infinity);
                              }
                            });
                          },
                        ),
                        Text(
                          '${_chosenFare?.toStringAsFixed(2) ?? '-'} DH',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.pink),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.pink),
                          onPressed: () {
                            setModalState(() {
                              if (_chosenFare != null) {
                                _chosenFare = _chosenFare! + 1;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context); // Close fare popup
                          // Show the "Looking for a driver" dialog
                          _showRideRequestStatus();
                          // Create the ride request
                          await _createRideRequest();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Get Driver',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _cancelCurrentRideRequest() async {
    if (_currentRideRequestId == null) return;
    try {
      await _rideRequestService.deleteRideRequest(_currentRideRequestId!);
      setState(() {
        _currentRideRequestId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride request cancelled.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error cancelling ride request.')),
      );
    }
  }

  void _shareRideDetails(RideRequest request) async {
    try {
      // Format the share text with a deep link
      final shareText = '''
🚗 Ride Details:
From: ${request.pickupLocation ?? 'Pickup location'}
To: ${request.destinationLocation ?? 'Destination location'}
Fare: ${request.fare.toStringAsFixed(2)} DH
Status: ${request.status}

Track this ride: deplacetoi://ride/${request.id}
Or visit: https://deplacetoi.com/ride/${request.id}
''';

      // Share the text using native share sheet
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

  void _showRideRequestStatus() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
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
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Loading Animation
                      SizedBox(
                        height: 200,
                        child: Lottie.asset(
                          'assets/animations/Animation - 1748773057383.json',
                          repeat: true,
                          animate: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Title
                      const Text(
                        'Looking for a driver...',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Description
                      const Text(
                        'Please wait while we find the perfect driver for you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Share Button
                      if (_currentRideRequestId != null)
                        ElevatedButton.icon(
                          onPressed: () {
                            final request = _pendingRequests.firstWhere(
                              (r) => r.id == _currentRideRequestId,
                            );
                            _shareRideDetails(request);
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Share Ride'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // X icon in the top right
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 28),
                      onPressed: () {
                        Navigator.pop(context);
                        _cancelCurrentRideRequest();
                      },
                      tooltip: 'Cancel ride request',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createRideRequest() async {
    print('Entered _createRideRequest');
    if (_currentPosition == null || _destinationLocation == null || _chosenFare == null) {
      print('Missing required data for ride request:');
      print('Current Position: ${_currentPosition != null}');
      print('Destination Location: ${_destinationLocation != null}');
      print('Chosen Fare: $_chosenFare');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing required information for ride request')),
      );
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('No authenticated user');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to request a ride')),
        );
        return;
      }

      print('Creating ride request with data:');
      print('Rider ID: ${user.id}');
      print('From: (${_currentPosition!.latitude}, ${_currentPosition!.longitude})');
      print('To: (${_destinationLocation!.latitude}, ${_destinationLocation!.longitude})');
      print('Fare: $_chosenFare');
      print('Pickup Address: ${_fromController.text}');
      print('Destination Address: ${_toController.text}');

      await _rideRequestService.createRideRequest(
        riderId: user.id,
        fromLat: _currentPosition!.latitude,
        fromLng: _currentPosition!.longitude,
        toLat: _destinationLocation!.latitude,
        toLng: _destinationLocation!.longitude,
        fare: _chosenFare!,
        pickupAddress: _fromController.text,
        destinationAddress: _toController.text,
      );
      print('Ride request created successfully');

      // Get the created ride request ID
      final requests = await _rideRequestService.getNearbyPendingRequests(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      print('Nearby pending requests: ${requests.length}');
      
      if (requests.isNotEmpty) {
        final latestRequest = requests.first;
        _currentRideRequestId = latestRequest.id;
        print('Subscribing to ride request updates for ID: ${latestRequest.id}');
        
        // Show the "Looking for a driver" dialog
        _showRideRequestStatus();
        
        // Subscribe to ride request updates
        _rideRequestSubscription?.cancel();
        _rideRequestSubscription = _rideRequestService
            .subscribeToRideRequestUpdates(latestRequest.id)
            .listen((request) async {
          print('Received ride request update: $request');
          if (request != null) {
            if (request.status == 'accepted') {
              // Close the "Looking for a driver" dialog
              if (mounted) {
                Navigator.of(context).pop(); // Close the loading dialog
              }
              
              // Show the driver on the way banner
              _showDriverOnTheWayBanner();
              
              // Fetch driver profile
              if (request.driverId != null) {
                final driverProfile = await UserService().getUserProfile(request.driverId!);
                final driverRating = await RatingService().getUserAverageRating(request.driverId!);
                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Column(
                        children: [
                          Icon(Icons.check_circle, color: const Color.fromARGB(255, 37, 219, 43), size: 48),
                          const SizedBox(height: 12),
                          const Text('Ride Accepted!', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (driverProfile != null) ...[
                            if (driverProfile.profileImageUrl != null)
                              CircleAvatar(
                                backgroundImage: NetworkImage(driverProfile.profileImageUrl!),
                                radius: 32,
                              ),
                            const SizedBox(height: 12),
                            Text(
                              driverProfile.name ?? 'Your driver',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(driverProfile.email ?? ''),
                            const SizedBox(height: 12),
                            DriverRatingBar(
                              rating: driverRating,
                              size: 24,
                              color: Colors.amber,
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                children: [
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
                                              style: TextStyle(
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
                          ],
                          const SizedBox(height: 16),
                          const Text('A driver has accepted your ride!')
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              }
            } else if (request.status == 'completed') {
              // Show rating dialog
              _showRatingDialog(request);
            }
          }
        }, onError: (error) {
          print('Error in ride request subscription: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error receiving ride updates')),
          );
        });
      } else {
        print('No pending requests found after creation');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Could not find created ride request')),
        );
      }
    } catch (e) {
      print('Error creating ride request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating ride request: ${e.toString()}')),
      );
    }
  }

  void _startLocationUpdates(String userId) {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        Position pos = await Geolocator.getCurrentPosition();
        await _locationService.updateLocation(userId, pos.latitude, pos.longitude);
      } catch (e) {
        // ignore
      }
    });
  }

  void _subscribeToDriverLocation(String driverId) {
    _otherLocationSub?.cancel();
    _otherLocationSub = _locationService.subscribeToUserLocation(driverId).listen((data) {
      if (data != null) {
        setState(() {
          _driverLocation = gmaps.LatLng(data['lat'], data['lng']);
        });
      }
    });
  }

  void _showRatingDialog(RideRequest request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingDialog(
        rideId: request.id,
        ratedUserId: request.driverId!,
        raterId: request.riderId,
        onRatingSubmitted: () {
          // Refresh the ratings if needed
          setState(() {});
        },
      ),
    );
  }

  void _handleRideStatusUpdate(RideRequest request) {
    if (request.status == 'completed') {
      _showRatingDialog(request);
    }
  }

  void _showDriverOnTheWayBanner() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              children: [
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage('assets/images/car.png'),
                      fit: BoxFit.contain,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Driver is on the way!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<Map<String, dynamic>?>(
                  stream: _locationService.subscribeToUserLocation(_currentRideRequestId ?? ''),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      final driverLat = snapshot.data!['lat'];
                      final driverLng = snapshot.data!['lng'];
                      
                      // Calculate distance
                      final distance = Geolocator.distanceBetween(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                        driverLat,
                        driverLng,
                      );
                      
                      String distanceText;
                      if (distance < 1000) {
                        distanceText = '${distance.toStringAsFixed(0)}m away';
                      } else {
                        distanceText = '${(distance / 1000).toStringAsFixed(1)}km away';
                      }
                      
                      return Column(
                        children: [
                          Text(
                            distanceText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.pink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Stack(
                            children: [
                              LinearProgressIndicator(
                                value: distance < 5000 ? 1 - (distance / 5000) : 0,
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.pink),
                              ),
                              Positioned(
                                right: 0,
                                top: -20,
                                child: Transform.translate(
                                  offset: Offset(
                                    (distance < 5000 ? 1 - (distance / 5000) : 0) * 200,
                                    0,
                                  ),
                                  child: Image.asset(
                                    'assets/images/car.png',
                                    width: 30,
                                    height: 30,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _getDriverStatus(distance),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    }
                    return const CircularProgressIndicator();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _cancelCurrentRideRequest();
                },
                child: const Text('Cancel Ride'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getDriverStatus(double distance) {
    if (distance < 100) {
      return 'Driver is very close!';
    } else if (distance < 500) {
      return 'Driver is nearby';
    } else if (distance < 1000) {
      return 'Driver is approaching';
    } else if (distance < 2000) {
      return 'Driver is on the way';
    } else {
      return 'Driver is heading to your location';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_currentPosition != null)
            gmaps.GoogleMap(
              initialCameraPosition: gmaps.CameraPosition(
                target: gmaps.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                zoom: 15,
              ),
              onMapCreated: (gmaps.GoogleMapController controller) {
                _mapController = controller;
              },
              markers: {
                ..._markers,
                if (_driverLocation != null)
                  gmaps.Marker(
                    markerId: const gmaps.MarkerId('driver_location'),
                    position: _driverLocation!,
                    icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure),
                    infoWindow: const gmaps.InfoWindow(title: 'Driver Location'),
                  ),
              },
              polylines: _polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onCameraMove: (gmaps.CameraPosition position) {
                setState(() {
                  _isCameraMoving = true;
                  _mapCenter = position.target;
                });
              },
              onCameraIdle: () async {
                if (_mapCenter != null) {
                  setState(() {
                    _isCameraMoving = false;
                  });
                  // Update destination to center
                  try {
                    List<Placemark> placemarks = await placemarkFromCoordinates(
                      _mapCenter!.latitude,
                      _mapCenter!.longitude,
                    );
                    if (placemarks.isNotEmpty) {
                      Placemark place = placemarks[0];
                      final address = '${place.street}, ${place.locality}, ${place.country}';
                      setState(() {
                        _destinationLocation = _mapCenter;
                        _toController.text = address;
                        _markers.removeWhere((m) => m.markerId.value == 'destination');
                      });
                    }
                  } catch (e) {
                    print('Error getting place details: $e');
                  }
                }
              },
            ),

          // Map Controls
          if (_currentPosition != null)
            Positioned(
              right: 16,
              bottom: 80,
              child: Column(
              children: [
                  FloatingActionButton(
                    heroTag: 'zoomIn',
                    onPressed: () {
                      _mapController?.animateCamera(
                        gmaps.CameraUpdate.zoomIn(),
                      );
                    },
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.add, color: Colors.pink),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: 'zoomOut',
                    onPressed: () {
                      _mapController?.animateCamera(
                        gmaps.CameraUpdate.zoomOut(),
                      );
                    },
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.remove, color: Colors.pink),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: 'myLocation',
                    onPressed: () {
                      if (_currentPosition != null) {
                        _mapController?.animateCamera(
                          gmaps.CameraUpdate.newLatLngZoom(gmaps.LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 15),
                        );
                      }
                    },
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: Colors.pink),
                  ),
                ],
              ),
            ),

          // Uber-style Pin Cursor Overlay (always center)
          IgnorePointer(
            child: Center(
              child: Lottie.asset(
              'assets/animations/Animation - 1748773057383.json',
              width: 100,
              height: 100,
              repeat: true,
              animate: true,
              ),
            ),
            ),

          // Search Boxes and UI
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            height: _isExpanded ? MediaQuery.of(context).size.height * 0.7 : 180,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_isExpanded ? 0.2 : 0.1),
                    blurRadius: _isExpanded ? 30 : 20,
                    offset: Offset(0, _isExpanded ? 15 : 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Toggle for method
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Type Place'),
                          selected: _useTypingMethod,
                          onSelected: (selected) {
                            setState(() {
                              _useTypingMethod = true;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Map Select'),
                          selected: !_useTypingMethod,
                          onSelected: (selected) {
                            setState(() {
                              _useTypingMethod = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  // App Bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text(
                          'DéplaceToi',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: CircleAvatar(
                            backgroundImage: _userProfile?.profileImageUrl != null
                                ? NetworkImage(_userProfile!.profileImageUrl!)
                                : null,
                            child: _userProfile?.profileImageUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          onPressed: _showUserMenu,
                        ),
                      ],
                    ),
                  ),
                  // Search Boxes
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // From TextField
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _fromController,
                            decoration: InputDecoration(
                              hintText: 'Where from?',
                              prefixIcon: const Icon(Icons.location_on, color: Colors.pink),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.my_location, color: Colors.pink),
                                onPressed: _getCurrentLocation,
                              ),
                            ),
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // To TextField or Map Select
                        if (_useTypingMethod)
                          Column(
                            children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                                  controller: _searchController,
                                  decoration: const InputDecoration(
                                    hintText: 'Type destination...',
                                    prefixIcon: Icon(Icons.search, color: Colors.pink),
                              border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(16),
                                  ),
                                  onChanged: _searchPlaces,
                                  onTap: () {
                                    print('Type destination field tapped');
                                  },
                                ),
                              ),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.pink),
                        ),
                      ),
                    )
                              else if (_suggestions.isEmpty && _searchController.text.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                      'Aucun Place',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                        ),
                      ),
                    )
                  else if (_suggestions.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on, color: Colors.pink),
                              title: Text(
                                          suggestion['main_text'],
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                          suggestion['secondary_text'],
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                                        onTap: () => _getPlaceDetails(suggestion['place_id'], true),
                            );
                          },
                        ),
                      ),
                            ],
                          )
                        else
                          Container(
                        decoration: BoxDecoration(
                              color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                            child: TextField(
                              controller: _toController,
                              decoration: const InputDecoration(
                                hintText: 'Move the map to select destination',
                                prefixIcon: Icon(Icons.location_on, color: Colors.pink),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(16),
                              ),
                              readOnly: true,
                                      ),
                                    ),
                                  ],
                                      ),
                                    ),
                                  ],
                                ),
            ),
          ),

          // Calculate Fare Button at the bottom
          if (_destinationLocation != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                  onPressed: _calculateRoute,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.pink,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                    'Calculate Fare',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _animationController.dispose();
    _mapController?.dispose();
    _positionStream?.cancel();
    _rideRequestSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _otherLocationSub?.cancel();
    super.dispose();
  }
} 