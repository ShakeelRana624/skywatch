import 'package:flutter/material.dart';
import 'map.dart';
import 'profile.dart';
import 'about.dart';
import 'session_manager.dart';
import 'login.dart';

import 'dart:math' as math;
import 'dart:ui';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class AmbulanceDashboardScreen extends StatefulWidget {
  const AmbulanceDashboardScreen({super.key});

  @override
  State<AmbulanceDashboardScreen> createState() =>
      _AmbulanceDashboardScreenState();
}

class _AmbulanceDashboardScreenState extends State<AmbulanceDashboardScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  // Screens: Map aur Profile
  final List<Widget> _screens = [const MapScreen(nearbyAlerts: []), const ProfileScreen()];

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Audio Player for notification
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isNotificationPlaying = false;
  final List<String> _processedRequestIds =
      []; // Track already processed requests

  // User Info
  String username = 'Ambulance Driver';
  String vehicleNumber = 'AMB-1122';
  String userRole = '1122';
  String _userId = '';

  // Location tracking
  bool _isOnline = false;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _locationUpdateTimer;

  // Assigned Alerts/Requests from Firestore
  List<Map<String, dynamic>> assignedRequests = [];

  // Radar Animation Controllers
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _blipController;
  final List<RadarBlip> _blips = [];

  // Loading states
  bool _isLoadingRequests = true;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _blipController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _generateBlips();

    _loadUserData().then((_) {
      _setupRequestsListener();
      _startLocationTracking();
      _initializeIovTracking(); // ✅ Initialize IOV tracking properly
    });

    // Setup audio player completion handler
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isNotificationPlaying = false;
      });
    });
  }

  Future<void> _playNotification() async {
    try {
      if (!_isNotificationPlaying) {
        setState(() {
          _isNotificationPlaying = true;
        });

        // Play notification sound from assets
        await _audioPlayer
            .play(AssetSource('amb.mp3')); // Different sound for ambulance

        // Automatically stop after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (_isNotificationPlaying) {
            _audioPlayer.stop();
            setState(() {
              _isNotificationPlaying = false;
            });
          }
        });
      }
    } catch (e) {
      print('Error playing notification: $e');
      setState(() {
        _isNotificationPlaying = false;
      });
    }
  }

  void _stopNotification() {
    if (_isNotificationPlaying) {
      _audioPlayer.stop();
      setState(() {
        _isNotificationPlaying = false;
      });
    }
  }
Future<void> _loadUserData() async {
  User? user = _auth.currentUser;
  if (user != null) {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        Map<String, dynamic> userData =
            userDoc.data() as Map<String, dynamic>;

        setState(() {
          username = userData['name'] ??
              userData['username'] ??
              userData['fullName'] ??
              'Ambulance Driver';

          vehicleNumber = userData['vehicleNumber'] ??
              userData['ambulanceNumber'] ??
              'AMB-1122';
          
          _userId = user.uid;
          _isLoadingUser = false;
        });

        print('Ambulance user data loaded: $username, $vehicleNumber');
        print('User UID: $_userId'); // ✅ Debug print
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoadingUser = false);
    }
  } else {
    setState(() => _isLoadingUser = false);
  }
}

  // 📍 NEW: Initialize IOV tracking
  Future<void> _initializeIovTracking() async {
    if (_userId.isEmpty) return;

    try {
      // Pehle IOV ko online mark karoam
      await _updateIovStatus('online');
      _isOnline = true;

      // Har 30 seconds mein location update karo (backup)
      _locationUpdateTimer =
          Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_currentPosition != null && _isOnline) {
          _updateIovLocation();
        }
      });

      print('✅ Ambulance IOV Tracking initialized for user: $_userId');
    } catch (e) {
      print('❌ Error initializing ambulance IOV tracking: $e');
    }
  }

  // 📍 NEW: Start location tracking for ambulance
  Future<void> _startLocationTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return;
      }

      // Get initial position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = position;

      // Start location updates
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        _currentPosition = position;
        _updateIovLocation();
      });

      print('✅ Ambulance location tracking started');
    } catch (e) {
      print('❌ Error starting location tracking: $e');
    }
  }
// Update these methods in your AmbulanceDashboardScreen class:

// 📍 FIXED: Update IOV status in Firebase Realtime Database
Future<void> _updateIovStatus(String status) async {
  if (_userId.isEmpty) return;

  try {
    Map<String, dynamic> iovData = {
      'username': username,  // ✅ Required field
      'carNumber': vehicleNumber,  // ✅ Required field
      'role': '1122',  // ✅ Must match rule (Police, Ambulance, or Fire)
      'status': status,  // ✅ Required field
      'lastUpdate': ServerValue.timestamp,  // ✅ Required field
      'userId': _userId,  // ✅ Required field (must match $iov_id)
      'lastSeen': DateTime.now().toIso8601String(),
      'isAvailable': true,
      'vehicleType': 'Ambulance',
    };

    // Optional location fields
    if (_currentPosition != null) {
      iovData['lat'] = _currentPosition!.latitude;
      iovData['lng'] = _currentPosition!.longitude;
      iovData['accuracy'] = _currentPosition!.accuracy;
      iovData['speed'] = _currentPosition!.speed;
    }

    // Device info
    iovData['deviceInfo'] = {
      'platform': 'android',
      'lastOnline': DateTime.now().toIso8601String(),
    };

    // ✅ Use set() for initial write, update() for subsequent writes
    final snapshot = await _database.child('iovs/$_userId').get();
    if (!snapshot.exists) {
      await _database.child('iovs/$_userId').set(iovData);
    } else {
      await _database.child('iovs/$_userId').update(iovData);
    }

    // ✅ Setup onDisconnect for auto-offline when app closes/crashes
    await _database.child('iovs/$_userId').onDisconnect().update({
      'status': 'offline',
      'lastUpdate': ServerValue.timestamp,
      'lastSeen': DateTime.now().toIso8601String(),
    });

    print('✅ Ambulance IOV status updated: $status');
  } catch (e) {
    print('❌ Error updating ambulance IOV status: $e');
  }
}

// 📍 FIXED: Update IOV location in Firebase
Future<void> _updateIovLocation() async {
  if (_userId.isEmpty || !_isOnline || _currentPosition == null) return;

  try {
    // ✅ Only update location fields (no validation issues)
    await _database.child('iovs/$_userId').update({
      'lat': _currentPosition!.latitude,
      'lng': _currentPosition!.longitude,
      'accuracy': _currentPosition!.accuracy,
      'speed': _currentPosition!.speed,
      'lastUpdate': ServerValue.timestamp,
      'status': 'online',
    });
    // print('📍 Location updated'); // Uncomment if needed
  } catch (e) {
    print('❌ Error updating ambulance location: $e');
  }
}

// 📍 FIXED: Set IOV offline when app closes
Future<void> _setIovOffline() async {
  if (_userId.isEmpty) return;

  try {
    await _database.child('iovs/$_userId').update({
      'status': 'offline',
      'lastUpdate': ServerValue.timestamp,
      'lastSeen': DateTime.now().toIso8601String(),
    });
    print('✅ Ambulance IOV set to offline');
  } catch (e) {
    print('❌ Error setting ambulance IOV offline: $e');
  }
}

// 📍 ADD MISSING FUNCTIONS
void _generateBlips() {
  final random = math.Random();
  for (int i = 0; i < 4; i++) {
    _blips.add(
      RadarBlip(
        angle: random.nextDouble() * 2 * math.pi,
        distance: 0.2 + random.nextDouble() * 0.6,
        size: 3 + random.nextDouble() * 3,
        speed: 1 + random.nextDouble() * 2,
      ),
    );
  }
}

void _setupRequestsListener() {
  User? user = _auth.currentUser;

  if (user != null) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('assigned_alerts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      List<Map<String, dynamic>> requests = [];
      List<String> currentRequestIds = [];

      for (var doc in snapshot.docs) {
        var data = doc.data();
        data['requestId'] = doc.id;
        currentRequestIds.add(doc.id);

        // Format request for display
        data['formattedTime'] = _formatFirestoreTime(data['timestamp']);

        // Only show pending/enroute requests
        String status = data['status'] ?? 'pending';
        if (status == 'pending' || status == 'enroute') {
          requests.add(data);

          // Check if this is a new request (not in processed list)
          if (!_processedRequestIds.contains(doc.id)) {
            // This is a new request, play notification
            print('🚑 New request detected: ${doc.id}');
            _playNotification();

            // Add to processed list
            _processedRequestIds.add(doc.id);
          }
        }
      }

      // Clean up processed requests list (remove old ones)
      _processedRequestIds
          .removeWhere((id) => !currentRequestIds.contains(id));

      setState(() {
        assignedRequests = requests;
        _isLoadingRequests = false;
        _updateRadarBlips(requests);
      });

      print('Loaded ${requests.length} assigned requests for ambulance');
    }, onError: (error) {
      print('Error loading requests: $error');
      setState(() {
        _isLoadingRequests = false;
      });
    });
  }
}

String _formatFirestoreTime(Timestamp? timestamp) {
  if (timestamp == null) return 'Just now';

  DateTime requestTime = timestamp.toDate();
  DateTime now = DateTime.now();
  Duration difference = now.difference(requestTime);

  if (difference.inSeconds < 60) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} min ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours} hours ago';
  } else {
    return '${difference.inDays} days ago';
  }
}

void _updateRadarBlips(List<Map<String, dynamic>> requests) {
  _blips.clear();

  for (int i = 0; i < requests.length && i < 8; i++) {
    final random = math.Random(i);
    _blips.add(
      RadarBlip(
        angle: random.nextDouble() * 2 * math.pi,
        distance: 0.2 + random.nextDouble() * 0.6,
        size: 4, // Fixed size for ambulance blips
        speed: 1 + random.nextDouble() * 2,
        requestId: requests[i]['requestId'],
        priority: requests[i]['alertDetails']?['priority'] ?? 'Medium',
      ),
    );
  }
}

// 📍 UPDATE dispose - ensure offline is set
@override
void dispose() {
  _radarController.dispose();
  _pulseController.dispose();
  _blipController.dispose();
  _audioPlayer.dispose();
  _positionStreamSubscription?.cancel();
  _locationUpdateTimer?.cancel(); // 👈 Timer cancel karo
  _setIovOffline(); // ✅ This will work now
  super.dispose();
}
  // Navigate to location using Google Maps
  Future<void> _navigateToLocation(Map<String, dynamic> request) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );

      // Get location from request
      Map<String, dynamic>? location = request['alertLocation'];

      if (location == null) {
        Navigator.pop(context); // Close loading
        _showErrorSnackBar('Location not available');
        return;
      }

      double destLat = location['lat'] ?? 0.0;
      double destLng = location['lng'] ?? 0.0;

      if (destLat == 0.0 || destLng == 0.0) {
        Navigator.pop(context); // Close loading
        _showErrorSnackBar('Invalid coordinates');
        return;
      }

      // Get current location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Navigator.pop(context); // Close loading
        _showErrorSnackBar('Please enable location services');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Navigator.pop(context); // Close loading
          _showErrorSnackBar('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Navigator.pop(context); // Close loading
        _showErrorSnackBar('Location permissions are permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      Navigator.pop(context); // Close loading

      // Launch Google Maps
      String googleMapsUrl = "https://www.google.com/maps/dir/?api=1"
          "&origin=${position.latitude},${position.longitude}"
          "&destination=$destLat,$destLng"
          "&travelmode=driving";

      final uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        // Update status to enroute
        _updateRequestStatus(request['requestId'], 'enroute');
      } else {
        _showErrorSnackBar('Could not launch Google Maps');
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showErrorSnackBar('Error: $e');
    }
  }

  // Update request status
  Future<void> _updateRequestStatus(String? requestId, String status) async {
    if (requestId == null) return;

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('ambulance_requests')
            .doc(requestId)
            .update({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Also update in assigned_alerts subcollection
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('assigned_alerts')
            .doc(requestId)
            .update({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        _showSuccessSnackBar('Status updated to $status');
      }
    } catch (e) {
      print('Error updating status: $e');
    }
  }

  // Mark request as completed
  Future<void> _markAsCompleted(String? requestId) async {
    if (requestId == null) return;

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('ambulance_requests')
            .doc(requestId)
            .update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('assigned_alerts')
            .doc(requestId)
            .update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });

        // Make ambulance available again
        await _firestore.collection('users').doc(user.uid).update({
          'isAvailable': true,
          'currentAssignment': null,
        });

        _showSuccessSnackBar('Request completed!');
      }
    } catch (e) {
      print('Error completing request: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: _selectedIndex == 0
          ? _buildDashboardView()
          : _screens[_selectedIndex - 1],
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // Dashboard View
  Widget _buildDashboardView() {
    return Stack(
      children: [
        // Background Image with Blur
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Notification Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Menu Button to open drawer
                        GestureDetector(
                          onTap: () {
                            _scaffoldKey.currentState?.openDrawer();
                          },
                          child: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.menu,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.red,
                              width: 2,
                            ),
                            image: const DecorationImage(
                              image: AssetImage('assets/pic.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome,',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            _isLoadingUser
                                ? const SizedBox(
                                    height: 20,
                                    width: 100,
                                    child: LinearProgressIndicator(
                                      color: Colors.red,
                                    ),
                                  )
                                : Text(
                                    username,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Notification Indicator
                        if (_isNotificationPlaying)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withOpacity(
                                              0.5 +
                                                  _pulseController.value * 0.3,
                                            ),
                                            blurRadius:
                                                5 + _pulseController.value * 3,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'NEW',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Vehicle Info
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.emergency,
                                color: Colors.red,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                vehicleNumber,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Live Radar
                _buildLiveRadarSection(),

                const SizedBox(height: 20),

                // Need Help Section (instead of Nearby Alerts)
                _buildNeedHelpSection(),

                const SizedBox(height: 20),

                // Status Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildChip('Available', Icons.check_circle, Colors.green),
                    const SizedBox(width: 8),
                    _buildChip('Emergency', Icons.emergency, Colors.red),
                    const SizedBox(width: 8),
                    _buildChip('24/7', Icons.access_time, Colors.blue),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // Stop Notification Button (appears when notification is playing)
        if (_isNotificationPlaying)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _stopNotification,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off,
                          color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'STOP NOTIFICATION',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Live Radar Section
  Widget _buildLiveRadarSection() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([
                _radarController,
                _pulseController,
                _blipController,
              ]),
              builder: (context, child) {
                return CustomPaint(
                  painter: AmbulanceRadarPainter(
                    radarValue: _radarController.value,
                    pulseValue: _pulseController.value,
                    blips: _blips,
                    blipValue: _blipController.value,
                  ),
                  size: const Size(double.infinity, 280),
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.2),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: const Icon(
                    Icons.emergency,
                    color: Colors.red,
                    size: 25,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 15,
              right: 15,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(
                                      0.5 + _pulseController.value * 0.3,
                                    ),
                                    blurRadius: 5 + _pulseController.value * 3,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'SCANNING',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${assignedRequests.length} requests',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              bottom: 10,
              left: 15,
              child: Text(
                'Range: 5km',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 15,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Active',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Need Help Section (Replaces Nearby Alerts)
  Widget _buildNeedHelpSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.emergency, color: Colors.red, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Need Help',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${assignedRequests.length} requests',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (_isLoadingRequests)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Colors.red),
              ),
            )
          else if (assignedRequests.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'No pending requests',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'You are available',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: assignedRequests.length,
              itemBuilder: (context, index) {
                final request = assignedRequests[index];
                return _buildNeedHelpItem(request);
              },
            ),
        ],
      ),
    );
  }

// Need Help Item with GO button
  Widget _buildNeedHelpItem(Map<String, dynamic> request) {
    // Check if this is a new request (highlight it)
    bool isNewRequest = _processedRequestIds.contains(request['requestId']) &&
        assignedRequests.indexOf(request) < 3;

    String status = request['status'] ?? 'pending';
    Map<String, dynamic>? alertDetails = request['alertDetails'] ?? {};
    Map<String, dynamic>? location = request['alertLocation'] ?? {};

    String incidentType = alertDetails?['type'] ?? 'Emergency';
    String locationName = request['alertLocationName'] ?? 'Unknown location';
    String timeStr = request['formattedTime'] ?? 'Just now';

    // Fixed color for all requests - Red for ambulance theme
    Color primaryColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNewRequest
            ? primaryColor.withOpacity(0.15)
            : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isNewRequest
              ? primaryColor.withOpacity(0.5)
              : primaryColor.withOpacity(0.3),
          width: isNewRequest ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emergency,
                  color: Colors.red,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incidentType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locationName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Location coordinates if available
          if (location != null && location['lat'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.pin_drop, color: Colors.white38, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${location['lat']?.toStringAsFixed(6)}°, ${location['lng']?.toStringAsFixed(6)}°',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Info row with time and status - Fixed overflow issue
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time and status row
              Row(
                children: [
                  // Time
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.white38, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        timeStr,
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: status == 'pending'
                          ? Colors.orange.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: status == 'pending' ? Colors.orange : Colors.blue,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Buttons row - wrapped to prevent overflow
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // GO Button
                  if (status != 'completed')
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _navigateToLocation(request),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 6,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.navigation, color: Colors.white, size: 12),
                              SizedBox(width: 3),
                              Text(
                                'GO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Complete button (only for enroute status)
                  if (status == 'enroute') const SizedBox(width: 6),
                  if (status == 'enroute')
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _markAsCompleted(request['requestId']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 12),
                              SizedBox(width: 3),
                              Text(
                                'Done',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(60),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGlassNavItem(
                  0,
                  Icons.home_outlined,
                  Icons.home,
                ),
                _buildGlassNavItem(1, Icons.location_pin, Icons.location_on),
                _buildGlassNavItem(2, Icons.person_outline, Icons.person),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassNavItem(
    int index,
    IconData outlineIcon,
    IconData filledIcon,
  ) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.all(isSelected ? 8 : 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.3),
                      Colors.redAccent.withOpacity(0.1),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  isSelected ? filledIcon : outlineIcon,
                  key: ValueKey(isSelected),
                  color: isSelected ? Colors.red : Colors.white70,
                  size: isSelected ? 26 : 22,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 3,
                width: isSelected ? 20 : 0,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // Drawer Widget
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withOpacity(0.95),
              Colors.black.withOpacity(0.85),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Drawer Header with User Info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.red,
                              width: 2,
                            ),
                            image: const DecorationImage(
                              image: AssetImage('assets/pic.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.emergency,
                                    color: Colors.red,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    userRole,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                vehicleNumber,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
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

              // Drawer Menu Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      title: 'Dashboard',
                      onTap: () {
                        setState(() => _selectedIndex = 0);
                        Navigator.pop(context);
                      },
                      isSelected: _selectedIndex == 0,
                    ),
                    _buildDrawerItem(
                      icon: Icons.location_pin,
                      selectedIcon: Icons.location_on,
                      title: 'Live Map',
                      onTap: () {
                        setState(() => _selectedIndex = 1);
                        Navigator.pop(context);
                      },
                      isSelected: _selectedIndex == 1,
                    ),
                    _buildDrawerItem(
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person,
                      title: 'Profile',
                      onTap: () {
                        setState(() => _selectedIndex = 2);
                        Navigator.pop(context);
                      },
                      isSelected: _selectedIndex == 2,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Divider(
                        color: Colors.white24,
                        height: 1,
                      ),
                    ),
                    _buildDrawerItem(
                      icon: Icons.help_outline,
                      selectedIcon: Icons.help,
                      title: 'About',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AboutPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Bottom Section - Logout
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: _buildDrawerItem(
                  icon: Icons.logout,
                  selectedIcon: Icons.logout,
                  title: 'Logout',
                  onTap: () async {
                    Navigator.pop(context);
                    await _logout();
                  },
                  isLogout: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Drawer Menu Item Widget
  Widget _buildDrawerItem({
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    bool isLogout = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Colors.red.withOpacity(0.3),
                    Colors.red.withOpacity(0.1),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(15),
          border: isSelected
              ? Border.all(
                  color: Colors.red.withOpacity(0.5),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isLogout
                  ? Colors.red
                  : isSelected
                      ? Colors.red
                      : Colors.white70,
              size: 24,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isLogout
                      ? Colors.red
                      : isSelected
                          ? Colors.white
                          : Colors.white70,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.red,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      
      // Clear session
      await SessionManager.clearSession();
      
      // Navigate to login screen and clear all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      print('Error logging out: $e');
    }
  }
}

// Radar Blip Class for Ambulance
class RadarBlip {
  final double angle;
  final double distance;
  final double size;
  final double speed;
  String? requestId;
  String? priority;

  RadarBlip({
    required this.angle,
    required this.distance,
    required this.size,
    required this.speed,
    this.requestId,
    this.priority,
  });
}

// Ambulance Radar Painter
class AmbulanceRadarPainter extends CustomPainter {
  final double radarValue;
  final double pulseValue;
  final List<RadarBlip> blips;
  final double blipValue;

  AmbulanceRadarPainter({
    required this.radarValue,
    required this.pulseValue,
    required this.blips,
    required this.blipValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    final circlePaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, circlePaint);
    }

    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      circlePaint,
    );
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      circlePaint,
    );

    final radarPaint = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final angle = radarValue * 2 * math.pi;
    final lineEnd = Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
    canvas.drawLine(center, lineEnd, radarPaint);

    final sweepPaint = Paint()
      ..color = Colors.red.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final sweepPath = Path();
    sweepPath.moveTo(center.dx, center.dy);
    sweepPath.lineTo(
      center.dx + math.cos(angle - 0.3) * radius,
      center.dy + math.sin(angle - 0.3) * radius,
    );
    sweepPath.lineTo(
      center.dx + math.cos(angle + 0.3) * radius,
      center.dy + math.sin(angle + 0.3) * radius,
    );
    sweepPath.close();
    canvas.drawPath(sweepPath, sweepPaint);

    for (var blip in blips) {
      final blipAngle = blip.angle + blipValue * blip.speed;
      final distance = blip.distance * radius;
      final x = center.dx + math.cos(blipAngle) * distance;
      final y = center.dy + math.sin(blipAngle) * distance;

      Color blipColor = Colors.red;
      if (blip.priority == 'Medium') {
        blipColor = Colors.orange;
      } else if (blip.priority == 'Low') {
        blipColor = Colors.blue;
      }

      final glowPaint = Paint()
        ..color = blipColor.withOpacity(0.3 + pulseValue * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(x, y), blip.size + 2, glowPaint);

      final blipPaint = Paint()
        ..color = blipColor.withOpacity(0.8 + pulseValue * 0.2);
      canvas.drawCircle(Offset(x, y), blip.size, blipPaint);

      // Draw cross for high priority
      if (blip.priority == 'High') {
        final crossPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5;

        canvas.drawLine(
          Offset(x - 4, y - 4),
          Offset(x + 4, y + 4),
          crossPaint,
        );
        canvas.drawLine(
          Offset(x + 4, y - 4),
          Offset(x - 4, y + 4),
          crossPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
