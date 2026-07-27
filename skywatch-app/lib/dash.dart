import 'package:flutter/material.dart';
import 'map.dart';
import 'profile.dart';
import 'alert.dart';
import 'active_alerts.dart';
import 'alert_history.dart';
import 'about.dart';
import 'session_manager.dart';
import 'login.dart';
import 'ambul.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';

void main() async {
  // Enable Firebase Auth persistence
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  
  // Initialize session from Firebase
  await SessionManager.initializeFromFirebase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IOV Dashboard',
      theme: ThemeData.dark(),
      home: FutureBuilder<bool>(
        future: SessionManager.isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              ),
            );
          }
          
          bool isLoggedIn = snapshot.data ?? false;
          
          if (isLoggedIn) {
            return const IovDashboardScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}

class IovDashboardScreen extends StatefulWidget {
  const IovDashboardScreen({super.key});

  @override
  State<IovDashboardScreen> createState() => _IovDashboardScreenState();
}

class _IovDashboardScreenState extends State<IovDashboardScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Audio Player for alarm
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmPlaying = false;
  final List<String> _processedAlertIds = [];

  // User Info
  String username = 'Officer';
  String carNumber = 'IOV-03';
  String userRole = 'Police';
  String _userId = ''; // 👈 NEW: User ID for IOV tracking

  // Alerts from Firebase Realtime Database
  List<Map<String, dynamic>> nearbyAlerts = [];

  // Radar Animation Controllers
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _blipController;
  final List<RadarBlip> _blips = [];

  // Loading states
  bool _isLoadingAlerts = true;
  bool _isLoadingUser = true;

  // Location variables
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  bool _isLocationServiceEnabled = false;

  // 👇 NEW: IOV Tracking variables
  Timer? _locationUpdateTimer;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _blipController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _loadUserData();
    _setupAlertsListener();
    _initializeLocation();

    // Setup audio player completion handler
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isAlarmPlaying = false;
      });
    });
  }

  // 📍 NEW: Initialize IOV tracking
  Future<void> _initializeIovTracking() async {
    if (_userId.isEmpty) return;

    try {
      // Pehle IOV ko online mark karo
      await _updateIovStatus('online');
      _isOnline = true;

      // Har 30 seconds mein location update karo (backup)
      _locationUpdateTimer =
          Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_currentPosition != null && _isOnline) {
          _updateIovLocation();
        }
      });

      print('✅ IOV Tracking initialized for user: $_userId');
    } catch (e) {
      print('❌ Error initializing IOV tracking: $e');
    }
  }

  // 📍 NEW: Update IOV status in Firebase
  Future<void> _updateIovStatus(String status) async {
    if (_userId.isEmpty) return;

    try {
      Map<String, dynamic> iovData = {
        'username': username,
        'carNumber': carNumber,
        'role': userRole,
        'status': status,
        'lastUpdate': ServerValue.timestamp,
        'userId': _userId,
      };

      // Location add karo agar available ho
      if (_currentPosition != null) {
        iovData['lat'] = _currentPosition!.latitude;
        iovData['lng'] = _currentPosition!.longitude;
        iovData['accuracy'] = _currentPosition!.accuracy;
        iovData['speed'] = _currentPosition!.speed;
      }

      // Device info add karo
      iovData['deviceInfo'] = {
        'platform': 'android', // Aap actual platform detect kar sakte ho
        'lastOnline': DateTime.now().toIso8601String(),
      };

      // Firebase mein save karo
      await _database.child('iovs/$_userId').set(iovData);

      print('✅ IOV status updated: $status');
    } catch (e) {
      print('❌ Error updating IOV status: $e');
    }
  }

  // 📍 NEW: Update IOV location in Firebase
  Future<void> _updateIovLocation() async {
    if (_userId.isEmpty || !_isOnline || _currentPosition == null) return;

    try {
      await _database.child('iovs/$_userId').update({
        'lat': _currentPosition!.latitude,
        'lng': _currentPosition!.longitude,
        'accuracy': _currentPosition!.accuracy,
        'speed': _currentPosition!.speed,
        'lastUpdate': ServerValue.timestamp,
        'status': 'online',
      });
    } catch (e) {
      print('❌ Error updating location: $e');
    }
  }

  // 📍 NEW: Set IOV offline when app closes
  Future<void> _setIovOffline() async {
    if (_userId.isEmpty) return;

    try {
      _isOnline = false;
      await _database.child('iovs/$_userId').update({
        'status': 'offline',
        'lastUpdate': ServerValue.timestamp,
        'lastSeen': DateTime.now().toIso8601String(),
      });
      print('✅ IOV set to offline');
    } catch (e) {
      print('❌ Error setting IOV offline: $e');
    }
  }

  // User data load karne ka function (Firestore se)
  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      _userId = user.uid; // 👈 Save user ID

      try {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          setState(() {
            username =
                userData['username'] ?? userData['fullName'] ?? 'Officer';
            userRole = userData['role'] ?? 'Police';

            if (userRole == 'Police') {
              carNumber = userData['carNumber'] ?? 'POL-001';
            } else {
              carNumber = userData['ambulanceNumber'] ?? 'AMB-1122';
            }

            _isLoadingUser = false;
          });

          print('User data loaded: $username, $carNumber, $userRole');

          // 👇 Initialize IOV tracking after loading user data
          _initializeIovTracking();
        }
      } catch (e) {
        print('Error loading user data: $e');
        setState(() => _isLoadingUser = false);
      }
    } else {
      setState(() => _isLoadingUser = false);
    }
  }

  // 1. Location initialize karne ka function (UPDATED)
  Future<void> _initializeLocation() async {
    // Pehle check karo location service enabled hai ya nahi
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled');
      _showLocationDialog();
      return;
    }

    // Permission check karo
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied');
        _showLocationDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied');
      _showLocationDialog();
      return;
    }

    // Current location lo
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (_currentPosition != null) {
        setState(() {
          _isLocationServiceEnabled = true;
        });

        // 👇 Pehli location milte hi IOV update karo
        if (_userId.isNotEmpty && _isOnline) {
          _updateIovLocation();
        }

        // 👇 IMPORTANT: Force reload alerts with new location
        _refreshAlerts();

        // Real-time location stream start karo
        _positionSubscription = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 100, // 100 meter change pe update
          ),
        ).listen((Position position) {
          setState(() {
            _currentPosition = position;
          });

          // 👇 Har location update pe IOV location update karo
          if (_userId.isNotEmpty && _isOnline) {
            _updateIovLocation();
          }

          // 👇 Refresh alerts on location change
          _refreshAlerts();
        });
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

// 👇 NEW: Force refresh alerts
  void _refreshAlerts() {
    if (_currentPosition == null) return;

    // Create a filtered list based on current position
    List<Map<String, dynamic>> refreshedAlerts = [];

    for (var alert in nearbyAlerts) {
      double? alertLat = alert['coordinates']?['lat'] ?? alert['latitude'];
      double? alertLng = alert['coordinates']?['lng'] ?? alert['longitude'];

      if (alertLat != null && alertLng != null) {
        double distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              alertLat,
              alertLng,
            ) /
            1000;

        if (distance <= 5.0) {
          alert['distance'] = '${distance.toStringAsFixed(1)} km';
          alert['rawDistance'] = distance;
          refreshedAlerts.add(alert);
        }
      } else {
        refreshedAlerts.add(alert);
      }
    }

    // Sort by distance
    refreshedAlerts.sort((a, b) {
      double aDist = a['rawDistance'] ?? double.infinity;
      double bDist = b['rawDistance'] ?? double.infinity;
      return aDist.compareTo(bDist);
    });

    setState(() {
      nearbyAlerts = refreshedAlerts;
      // 🎯 UPDATE: Only show nearby alerts on radar (within 5km)
      _updateRadarBlips(refreshedAlerts);
    });
  }

  void _setupAlertsListener() {
    _database
        .child('alerts')
        .orderByChild('timestamp')
        .limitToLast(20)
        .onValue
        .listen((event) {
      DataSnapshot snapshot = event.snapshot;

      if (snapshot.value != null) {
        Map<dynamic, dynamic> alertsMap =
            snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> alerts = [];
        List<String> currentAlertIds = [];

        alertsMap.forEach((key, value) {
          Map<String, dynamic> alert = Map<String, dynamic>.from(value);
          String alertId = key.toString();
          alert['id'] = alertId;
          currentAlertIds.add(alertId);

          // 🎯 IMPORTANT: Extract data according to your Firebase structure
          String weaponType =
              alert['type'] ?? alert['weapon_class'] ?? 'Unknown';
          double confidence = alert['confidence']?.toDouble() ?? 0.0;
          String location = alert['Area'] ??
              alert['location']?['address'] ??
              'Unknown location';

          // Get coordinates if available
          double? lat = alert['latitude'] ?? alert['location']?['lat'];
          double? lng = alert['longitude'] ?? alert['location']?['lng'];

          // Set priority based on confidence
          String priority = 'Medium';
          if (confidence > 0.8) {
            priority = 'High';
          } else if (confidence > 0.5) {
            priority = 'Medium';
          } else {
            priority = 'Low';
          }

          // Create formatted alert for display
          alert['type'] = weaponType;
          alert['priority'] = priority;
          alert['location'] = location;
          alert['area'] = location;
          alert['time'] = _formatTime(alert['timestamp']);

          // Store coordinates
          if (lat != null && lng != null) {
            alert['coordinates'] = {'lat': lat, 'lng': lng};
          }

          // 👇👇👇 ADD THIS: Pre-filter by distance if location available
          bool shouldAddAlert = false;

          if (alert['status'] == 'active' || alert['status'] == null) {
            if (_currentPosition != null && lat != null && lng != null) {
              double distance = Geolocator.distanceBetween(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                    lat,
                    lng,
                  ) /
                  1000;

              if (distance <= 5.0) {
                shouldAddAlert = true;
                alert['distance'] = '${distance.toStringAsFixed(1)} km';
                alert['rawDistance'] = distance;
              }
            } else {
              // Agar location nahi hai to show karo
              shouldAddAlert = true;
            }
          }

          if (shouldAddAlert) {
            alerts.add(alert);

            // Check if this is a new alert (not in processed list)
            if (!_processedAlertIds.contains(alertId)) {
              // This is a new alert, play alarm
              print('🚨 New alert detected: $alertId');
              _playAlarm();

              // Add to processed list
              _processedAlertIds.add(alertId);
            }
          }
          // 👆👆👆
        });

        // Clean up processed alerts list
        _processedAlertIds.removeWhere((id) =>
            !currentAlertIds.contains(id) ||
            (alertsMap[id]?['status'] != 'active' &&
                alertsMap[id]?['status'] != 'pending'));

        // Sort by timestamp (newest first)
        alerts.sort((a, b) {
          int aTime = a['timestamp'] ?? 0;
          int bTime = b['timestamp'] ?? 0;
          return bTime.compareTo(aTime);
        });

        setState(() {
          nearbyAlerts = alerts;
          _isLoadingAlerts = false;
          // 🎯 REMOVED: Don't update radar here - wait for distance filtering
        });
        
        // 🎯 IMPORTANT: Filter alerts by distance after loading
        if (_currentPosition != null) {
          _refreshAlerts();
        }

        print('Loaded ${alerts.length} alerts from Firebase');
      } else {
        setState(() {
          nearbyAlerts = [];
          _isLoadingAlerts = false;
        });
      }
    });
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) return 'Just now';

    DateTime alertTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    DateTime now = DateTime.now();
    Duration difference = now.difference(alertTime);

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

  void _updateAlertDistances() {
    if (_currentPosition == null || nearbyAlerts.isEmpty) return;

    List<Map<String, dynamic>> filteredAlerts = [];

    for (var alert in nearbyAlerts) {
      double? alertLat = alert['coordinates']?['lat'] ?? alert['latitude'];
      double? alertLng = alert['coordinates']?['lng'] ?? alert['longitude'];

      if (alertLat != null && alertLng != null) {
        double distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              alertLat,
              alertLng,
            ) /
            1000; // meters to kilometers

        alert['distance'] = '${distance.toStringAsFixed(1)} km';
        alert['rawDistance'] = distance;

        // 👇 ONLY KEEP ALERTS WITHIN 5km
        if (distance <= 5.0) {
          filteredAlerts.add(alert);
          print('✅ Alert within 5km: ${distance.toStringAsFixed(2)}km');
        } else {
          print(
              '❌ Alert outside 5km: ${distance.toStringAsFixed(2)}km - HIDDEN');
        }
        // 👆
      } else {
        alert['distance'] = 'Unknown';
        alert['rawDistance'] = double.infinity;
        filteredAlerts.add(alert); // Keep alerts without location
      }
    }

    // Sort by distance (nearest first)
    filteredAlerts.sort((a, b) {
      double aDist = a['rawDistance'] ?? double.infinity;
      double bDist = b['rawDistance'] ?? double.infinity;
      return aDist.compareTo(bDist);
    });

    // 👇 IMPORTANT: Only update if lists are different
    if (_areListsDifferent(nearbyAlerts, filteredAlerts)) {
      setState(() {
        nearbyAlerts = filteredAlerts;
        // 🎯 UPDATE: Only show nearby alerts on radar (within 5km)
        _updateRadarBlips(filteredAlerts);
      });
    }
  }

// Helper function to check if lists are different
  bool _areListsDifferent(
      List<Map<String, dynamic>> list1, List<Map<String, dynamic>> list2) {
    if (list1.length != list2.length) return true;

    for (int i = 0; i < list1.length; i++) {
      if (list1[i]['id'] != list2[i]['id']) return true;
    }

    return false;
  }

  void _updateRadarBlips(List<Map<String, dynamic>> alerts) {
    _blips.clear();

    // 🎯 DEBUG: Show how many alerts are being shown on radar
    print('🎯 Radar: Showing ${alerts.length} nearby alerts (within 5km)');

    for (int i = 0; i < alerts.length && i < 8; i++) {
      final random = math.Random(i);
      _blips.add(
        RadarBlip(
          angle: random.nextDouble() * 2 * math.pi,
          distance: 0.2 + random.nextDouble() * 0.6,
          size: 5,
          speed: 1 + random.nextDouble() * 2,
          alertId: alerts[i]['id'],
          alertType: alerts[i]['type'],
        ),
      );
    }
  }

  Future<void> _playAlarm() async {
    try {
      if (!_isAlarmPlaying) {
        setState(() {
          _isAlarmPlaying = true;
        });

        // Play alarm sound from assets
        await _audioPlayer.play(AssetSource('alert.mp3'));

        // Automatically stop after 7 seconds
        Future.delayed(const Duration(seconds: 7), () {
          if (_isAlarmPlaying) {
            _audioPlayer.stop();
            setState(() {
              _isAlarmPlaying = false;
            });
          }
        });
      }
    } catch (e) {
      print('Error playing alarm: $e');
      setState(() {
        _isAlarmPlaying = false;
      });
    }
  }

  void _stopAlarm() {
    if (_isAlarmPlaying) {
      _audioPlayer.stop();
      setState(() {
        _isAlarmPlaying = false;
      });
    }
  }

  // Location na milne par dialog dikhane ka function
  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Required'),
        content: const Text(
            'Please enable location services to see accurate distances to alerts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    _blipController.dispose();
    _audioPlayer.dispose();
    _positionSubscription?.cancel();
    _locationUpdateTimer?.cancel(); // 👈 Timer cancel karo

    // 👈 App close hote hi IOV ko offline karo
    _setIovOffline();

    super.dispose();
  }

  // 👇 NEW: Logout function
  Future<void> _logout() async {
    // Pehle IOV ko offline karo
    await _setIovOffline();

    // Phir logout karo
    await _auth.signOut();

    // Clear session
    await SessionManager.clearSession();

    // Navigate to login screen and clear all previous routes
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _navigateToAlertDetails(Map<String, dynamic> alert) {
    // Stop alarm when navigating to alert
    _stopAlarm();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AlertDetailsPage(alert: alert)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: _selectedIndex == 0
          ? _buildDashboardView()
          : _getScreens()[_selectedIndex - 1],
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // Build screens with nearbyAlerts passed to MapScreen
  List<Widget> _getScreens() {
    return [
      MapScreen(nearbyAlerts: nearbyAlerts),
      const ProfileScreen(),
    ];
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
                // Header with Alarm Indicator
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
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                              border: Border.all(
                                color: Colors.blueAccent.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.menu,
                              color: Colors.white70,
                              size: 22,
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
                              color: Colors.blueAccent,
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
                                      color: Colors.blueAccent,
                                    ),
                                  )
                                : Text(
                                    username,
                                    style: TextStyle(
                                      color: Colors.blueAccent,
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
                        // Alarm Indicator
                        if (_isAlarmPlaying)
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
                                  'ALARM',
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
                            color: userRole == 'Police'
                                ? Colors.blueAccent.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: userRole == 'Police'
                                  ? Colors.blueAccent.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                userRole == 'Police'
                                    ? Icons.local_police
                                    : Icons.emergency,
                                color: userRole == 'Police'
                                    ? Colors.blueAccent
                                    : Colors.red,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                carNumber,
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

                // Alerts Section
                _buildNearbyAlertsSection(),

                const SizedBox(height: 20),

                // Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildChip('Weapon', Icons.gavel),
                    const SizedBox(width: 8),
                    _buildChip('Violence', Icons.local_fire_department),
                    const SizedBox(width: 8),
                    _buildChip('Fire', Icons.psychology),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // Stop Alarm Button (appears when alarm is playing)
        if (_isAlarmPlaying)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _stopAlarm,
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
                      Icon(Icons.alarm_off, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'STOP ALARM',
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
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
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
                  painter: RadarPainter(
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
                    color: Colors.redAccent.withOpacity(0.2),
                    border: Border.all(color: Colors.redAccent, width: 2),
                  ),
                  child: const Icon(
                    Icons.radar,
                    color: Colors.redAccent,
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
                          'LIVE SCANNING',
                          style: TextStyle(
                            color: Colors.redAccent,
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
                      '${nearbyAlerts.length} targets',
                      style: const TextStyle(
                        color: Colors.greenAccent,
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
                'Range: 3km',
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
                      color: Colors.green,
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

  // Alerts Section
  Widget _buildNearbyAlertsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.crisis_alert, color: Colors.blueAccent, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Nearby Alerts',
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
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${nearbyAlerts.length} nearby',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (_isLoadingAlerts)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
            )
          else if (nearbyAlerts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No active alerts nearby',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: nearbyAlerts.length,
              itemBuilder: (context, index) {
                final alert = nearbyAlerts[index];
                return _buildNearbyAlertItem(alert);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNearbyAlertItem(Map<String, dynamic> alert) {
    Color priorityColor;
    switch (alert['priority'] ?? 'Medium') {
      case 'High':
        priorityColor = Colors.blueAccent;
        break;
      case 'Medium':
        priorityColor = Colors.blue;
        break;
      default:
        priorityColor = Colors.blue.shade300;
    }

    // Check if this is a new alert (highlight it)
    bool isNewAlert = _processedAlertIds.contains(alert['id']) &&
        nearbyAlerts.indexOf(alert) < 3; // First few alerts

    String weaponType = alert['type'] ?? 'Unknown';
    double confidence = alert['confidence'] ?? 0.0;
    String location = alert['location'] ?? alert['location_name'] ?? 'Unknown';
    String timeStr = alert['time'] ?? 'Just now';
    String distance = alert['distance'] ?? '0.5 km';
    String cameraName = alert['camera_name'] ?? 'CAM-001';

    return GestureDetector(
      onTap: () => _navigateToAlertDetails(alert),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isNewAlert
              ? priorityColor.withOpacity(0.1) // Highlight new alerts
              : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isNewAlert
                ? priorityColor.withOpacity(0.5)
                : priorityColor.withOpacity(0.3),
            width: isNewAlert ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.emergency, color: priorityColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              weaponType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${(confidence * 100).toStringAsFixed(0)}% confidence',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
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
                          color: priorityColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          alert['priority'] ?? 'Medium',
                          style: TextStyle(
                            color: priorityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    location,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // FIXED SECTION - Using Wrap instead of Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      // Time
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time,
                              color: Colors.white, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            timeStr,
                            style:
                                TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ],
                      ),

                      // Distance
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route, color: Colors.white, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            distance,
                            style:
                                TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ],
                      ),

                      // Camera
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam,
                                color: Colors.white, size: 10),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                cameraName,
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
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
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _acceptAlert(alert),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Accept',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(int? timestamp) {
    if (timestamp == null) return 'Just now';
    int now = DateTime.now().millisecondsSinceEpoch;
    int difference = now - timestamp;
    if (difference < 60000) return 'Just now';
    if (difference < 3600000) return '${(difference / 60000).round()} min ago';
    if (difference < 86400000) {
      return '${(difference / 3600000).round()} hours ago';
    }
    return '${(difference / 86400000).round()} days ago';
  }

  void _acceptAlert(Map<String, dynamic> alert) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _database.child('alerts/${alert['id']}').update({
          'status': 'accepted',
          'acceptedBy': username,
          'acceptedAt': DateTime.now().toString(),
          'acceptedById': user.uid,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alert accepted: ${alert['type']}'),
            backgroundColor: Colors.green,
          ),
        );

        _navigateToAlertDetails(alert);
      }
    } catch (e) {
      print('Error accepting alert: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting alert'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(60),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.2),
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
                      Colors.blueAccent.withOpacity(0.3),
                      Colors.lightBlueAccent.withOpacity(0.1),
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
                  color: isSelected ? Colors.blueAccent : Colors.white70,
                  size: isSelected ? 26 : 22,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 3,
                width: isSelected ? 20 : 0,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
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
                      Colors.blueAccent.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.blueAccent.withOpacity(0.3),
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
                              color: Colors.blueAccent,
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
                                    userRole == 'Police'
                                        ? Icons.local_police
                                        : Icons.emergency,
                                    color: userRole == 'Police'
                                        ? Colors.blueAccent
                                        : Colors.red,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    userRole,
                                    style: TextStyle(
                                      color: userRole == 'Police'
                                          ? Colors.blueAccent
                                          : Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                carNumber,
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
                      icon: Icons.notifications_active_outlined,
                      selectedIcon: Icons.notifications_active,
                      title: 'Active Alerts',
                      badge: nearbyAlerts.isNotEmpty
                          ? nearbyAlerts.length.toString()
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActiveAlertsPage(nearbyAlerts: nearbyAlerts),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.history,
                      selectedIcon: Icons.history,
                      title: 'Alert History',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AlertHistoryPage(),
                          ),
                        );
                      },
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
    String? badge,
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
                    Colors.blueAccent.withOpacity(0.3),
                    Colors.blueAccent.withOpacity(0.1),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(15),
          border: isSelected
              ? Border.all(
                  color: Colors.blueAccent.withOpacity(0.5),
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
                      ? Colors.blueAccent
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
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isSelected)
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.blueAccent,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}

// Radar Blip Class
class RadarBlip {
  final double angle;
  final double distance;
  final double size;
  final double speed;
  String? alertId;
  String? alertType;

  RadarBlip({
    required this.angle,
    required this.distance,
    required this.size,
    required this.speed,
    this.alertId,
    this.alertType,
  });
}

// Radar Painter Class
class RadarPainter extends CustomPainter {
  final double radarValue;
  final double pulseValue;
  final List<RadarBlip> blips;
  final double blipValue;

  RadarPainter({
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
      ..color = Colors.redAccent.withOpacity(0.3)
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
      ..color = Colors.greenAccent.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final angle = radarValue * 2 * math.pi;
    final lineEnd = Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
    canvas.drawLine(center, lineEnd, radarPaint);

    final sweepPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.15)
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

      final glowPaint = Paint()
        ..color = blipColor.withOpacity(0.3 + pulseValue * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(x, y), blip.size + 2, glowPaint);

      final blipPaint = Paint()
        ..color = blipColor.withOpacity(0.8 + pulseValue * 0.2);
      canvas.drawCircle(Offset(x, y), blip.size, blipPaint);

      if (blip.size > 5) {
        final ringPaint = Paint()
          ..color = Colors.blueAccent.withOpacity(0.3 + pulseValue * 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawCircle(Offset(x, y), blip.size + 3, ringPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
