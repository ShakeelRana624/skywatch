import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'alert.dart';

class ActiveAlertsPage extends StatefulWidget {
  final List<Map<String, dynamic>>? nearbyAlerts;
  const ActiveAlertsPage({super.key, this.nearbyAlerts});

  @override
  State<ActiveAlertsPage> createState() => _ActiveAlertsPageState();
}

class _ActiveAlertsPageState extends State<ActiveAlertsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  List<Map<String, dynamic>> activeAlerts = [];
  bool _isLoading = true;
  Position? _currentPosition;

  // User Info
  String username = 'Officer';
  String userRole = 'Police';
  String carNumber = 'IOV-03';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    
    // If nearbyAlerts passed from parent, use them
    if (widget.nearbyAlerts != null) {
      setState(() {
        activeAlerts = widget.nearbyAlerts!;
        _isLoading = false;
      });
    } else {
      // Otherwise fetch independently
      _initializeLocation();
      _setupAlertsListener();
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
            username =
                userData['username'] ?? userData['fullName'] ?? 'Officer';
            userRole = userData['role'] ?? 'Police';

            if (userRole == 'Police') {
              carNumber = userData['carNumber'] ?? 'POL-001';
            } else {
              carNumber = userData['ambulanceNumber'] ?? 'AMB-1122';
            }
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _setupAlertsListener() {
    _database
        .child('alerts')
        .orderByChild('timestamp')
        .limitToLast(50)
        .onValue
        .listen((event) {
      DataSnapshot snapshot = event.snapshot;

      if (snapshot.value != null) {
        Map<dynamic, dynamic> alertsMap =
            snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> alerts = [];

        alertsMap.forEach((key, value) {
          Map<String, dynamic> alert = Map<String, dynamic>.from(value);
          alert['id'] = key.toString();

          // Only show active/pending alerts
          if (alert['status'] == 'active' || alert['status'] == 'pending') {
            String weaponType =
                alert['type'] ?? alert['weapon_class'] ?? 'Unknown';
            double confidence = alert['confidence']?.toDouble() ?? 0.0;
            String location = alert['Area'] ??
                alert['location']?['address'] ??
                'Unknown location';

            double? lat = alert['latitude'] ?? alert['location']?['lat'];
            double? lng = alert['longitude'] ?? alert['location']?['lng'];

            String priority = 'Medium';
            if (confidence > 0.8) {
              priority = 'High';
            } else if (confidence > 0.5) {
              priority = 'Medium';
            } else {
              priority = 'Low';
            }

            alert['type'] = weaponType;
            alert['priority'] = priority;
            alert['location'] = location;
            alert['time'] = _formatTime(alert['timestamp']);

            if (lat != null && lng != null) {
              alert['coordinates'] = {'lat': lat, 'lng': lng};

              // Calculate distance if current position available
              if (_currentPosition != null) {
                double distance = Geolocator.distanceBetween(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                      lat,
                      lng,
                    ) /
                    1000;
                alert['distance'] = '${distance.toStringAsFixed(1)} km';
                alert['rawDistance'] = distance;

                // Only add alerts within 5km (same as dashboard)
                if (distance <= 5.0) {
                  alerts.add(alert);
                }
              } else {
                // If location not available, still add the alert
                alerts.add(alert);
              }
            } else {
              // If no coordinates, still add the alert
              alerts.add(alert);
            }
          }
        });

        // Sort by timestamp (newest first)
        alerts.sort((a, b) {
          int aTime = a['timestamp'] ?? 0;
          int bTime = b['timestamp'] ?? 0;
          return bTime.compareTo(aTime);
        });

        setState(() {
          activeAlerts = alerts;
          _isLoading = false;
        });
      } else {
        setState(() {
          activeAlerts = [];
          _isLoading = false;
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

  void _navigateToAlertDetails(Map<String, dynamic> alert) {
    // Navigate to alert details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertDetailsPage(alert: alert),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.blueAccent;
      case 'Medium':
        return Colors.blue;
      default:
        return Colors.blue.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
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
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
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
                            Icons.arrow_back,
                            color: Colors.white70,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Alerts',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${activeAlerts.length} active incidents',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Alerts List
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.blueAccent,
                          ),
                        )
                      : activeAlerts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.task_alt,
                                    size: 80,
                                    color: Colors.blueAccent.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'No Active Alerts',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'All incidents have been resolved',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              itemCount: activeAlerts.length,
                              itemBuilder: (context, index) {
                                final alert = activeAlerts[index];
                                return _buildAlertCard(alert);
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    Color priorityColor = _getPriorityColor(alert['priority'] ?? 'Medium');
    String weaponType = alert['type'] ?? 'Unknown';
    double confidence = alert['confidence']?.toDouble() ?? 0.0;
    String location = alert['location'] ?? 'Unknown';
    String time = alert['time'] ?? 'Just now';
    String? distance = alert['distance'];

    return GestureDetector(
      onTap: () => _navigateToAlertDetails(alert),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: priorityColor.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.emergency,
                          color: priorityColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              weaponType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(confidence * 100).toStringAsFixed(0)}% confidence',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: priorityColor.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          alert['priority'] ?? 'Medium',
                          style: TextStyle(
                            color: priorityColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.white.withOpacity(0.5),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.white.withOpacity(0.5),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            time,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                          if (distance != null) ...[
                            const SizedBox(width: 15),
                            Icon(
                              Icons.route,
                              color: Colors.white.withOpacity(0.5),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              distance,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _acceptAlert(alert),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.withOpacity(0.3),
                                Colors.green.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.5),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Accept',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
