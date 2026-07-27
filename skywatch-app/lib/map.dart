import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class MapScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? nearbyAlerts;
  const MapScreen({super.key, this.nearbyAlerts});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  LatLng? _currentPosition;
  final MapController _mapController = MapController();

  bool _isLoading = true;
  String? _locationError;
  
  // Cache for faster loading
  LatLng? _lastKnownPosition;

  late AnimationController _bgController;
  late Animation<double> _bgOpacity;

  // Firebase & Location Tracking
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  StreamSubscription<Position>? _positionStreamSubscription;
  String? _userId;
  String? _username; // 👈 NEW: Username store karne ke liye

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _bgOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));
    _bgController.forward();

    _initializeUser();
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _stopLocationTracking();
    super.dispose();
  }

  void _initializeUser() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      // 👇 Username Firebase se le rahe hain (displayName se)
      _username =
          user.displayName ?? user.email?.split('@').first ?? 'Anonymous';

      // Agar displayName null hai to email se username bana rahe hain
      if (user.displayName == null && user.email != null) {
        _username = user.email!.split('@').first;
      }

      print('✅ User initialized: $_username (ID: $_userId)');
    } else {
      // Guest user ke liye
      _userId = DateTime.now().millisecondsSinceEpoch.toString();
      _username = 'Guest_${_userId!.substring(_userId!.length - 6)}';
      print('⚠️ Guest user: $_username');
    }
  }

  Future<void> _checkLocationPermission() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    PermissionStatus status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
    }

    if (!mounted) return;

    if (status.isGranted) {
      _getCurrentLocation();
      _startLocationTracking();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _locationError =
            'Location permission permanently denied. Please enable from settings.';
        _isLoading = false;
      });
    } else {
      setState(() {
        _locationError = 'Location permission denied';
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services are disabled';
          _isLoading = false;
        });
        return;
      }

      // Medium accuracy for faster response (high accuracy slow hoti hai)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      _updateLocationInFirebase(position.latitude, position.longitude);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_currentPosition != null && mounted) {
          _mapController.move(_currentPosition!, 15);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium, // Medium for better performance
      distanceFilter: 10,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      _updateLocationInFirebase(position.latitude, position.longitude);
      _mapController.move(_currentPosition!, 15);
    });
  }

  void _stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    if (_userId != null) {
      // Use iovs node since 1122 users have permission here
      _databaseRef.child('iovs/$_userId').update({
        'status': 'offline',
        'lastUpdate': ServerValue.timestamp,
      });
    }
  }

  // 👇 UPDATED: Only update iovs node (which 1122 users have permission for)
  Future<void> _updateLocationInFirebase(
      double latitude, double longitude) async {
    if (_userId == null) return;

    try {
      // Only write to iovs node since 1122 users have permission here
      await _databaseRef.child('iovs/$_userId').update({
        'lat': latitude,
        'lng': longitude,
        'lastUpdate': ServerValue.timestamp,
        'status': 'online',
      });

      print('✅ Location updated for user: $_username');
      print('📍 Coordinates: $latitude, $longitude');
    } catch (e) {
      print('❌ Error updating location in Firebase: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Animation
        TweenAnimationBuilder(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
          builder: (context, double value, child) {
            return Opacity(
              opacity: value,
              child: Stack(
                children: [
                  Image.asset(
                    'assets/log.png',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.black,
                        child: const Center(
                          child: Text(
                            'Background image not found',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.2),
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Dark Overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.black.withOpacity(0.5),
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
        ),

        // Main Content
        SafeArea(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.blueAccent),
                      SizedBox(height: 20),
                      Text(
                        'Getting your location...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              : _locationError != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_off,
                              size: 80, color: Colors.red),
                          const SizedBox(height: 20),
                          Text(
                            _locationError!,
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _checkLocationPermission,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _currentPosition == null
                      ? const Center(
                          child: Text(
                            'Unable to get location',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : Stack(
                          children: [
                            // Live Map
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _currentPosition!,
                                initialZoom: 15,
                                maxZoom: 19,
                                minZoom: 3,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.example.fypapp',
                                ),
                                MarkerLayer(
                                  markers: _buildMarkers(),
                                ),
                              ],
                            ),
                            // Top gradient
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.5),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // 👇 UPDATED: Username ke saath coordinates dikha rahe hain
                            Positioned(
                              top: 20,
                              left: 20,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.blueAccent.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.circle,
                                          color: Colors.green,
                                          size: 10,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Live Tracking - $_username', // 👈 Username yahan show ho raha hai
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
        ),
      ],
    );
  }

  // Custom Car Marker Widget for IOV Location
  Widget _buildCarMarker() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blueAccent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.directions_car,
        color: Colors.blueAccent,
        size: 28,
      ),
    );
  }

  // Custom Threat Marker Widget for Alert Locations
  Widget _buildThreatMarker(String alertType) {
    Color markerColor;
    IconData markerIcon;

    if (alertType.toLowerCase().contains('accident') ||
        alertType.toLowerCase().contains('weapon')) {
      markerColor = Colors.red;
      markerIcon = Icons.warning_rounded;
    } else if (alertType.toLowerCase().contains('fighting')) {
      markerColor = Colors.orange;
      markerIcon = Icons.local_fire_department;
    } else if (alertType.toLowerCase().contains('theft')) {
      markerColor = Colors.purple;
      markerIcon = Icons.lock_open;
    } else {
      markerColor = Colors.red;
      markerIcon = Icons.warning_rounded;
    }

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: markerColor.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: markerColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: markerColor.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        markerIcon,
        color: markerColor,
        size: 16,
      ),
    );
  }

  // Build markers list including alerts and current location
  List<Marker> _buildMarkers() {
    List<Marker> markers = [];

    // Add IOV car marker at current location
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: _currentPosition!,
          width: 50,
          height: 50,
          child: _buildCarMarker(),
        ),
      );
    }

    // Add threat markers for nearby alerts
    if (widget.nearbyAlerts != null) {
      for (var alert in widget.nearbyAlerts!) {
        double? lat = alert['coordinates']?['lat'] ?? alert['latitude'];
        double? lng = alert['coordinates']?['lng'] ?? alert['longitude'];
        String type = alert['type'] ?? 'Unknown';

        if (lat != null && lng != null) {
          markers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 30,
              height: 30,
              child: _buildThreatMarker(type),
            ),
          );
        }
      }
    }

    return markers;
  }

  // Custom Location Marker Widget
  Widget _buildLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer pulse effect
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withOpacity(0.2),
          ),
        ),
        // Inner circle
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withOpacity(0.4),
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
        // Center dot
        Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }
}
