import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AlertHistoryPage extends StatefulWidget {
  const AlertHistoryPage({super.key});

  @override
  State<AlertHistoryPage> createState() => _AlertHistoryPageState();
}

class _AlertHistoryPageState extends State<AlertHistoryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  List<Map<String, dynamic>> alertHistory = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all, accepted, resolved, dismissed

  // User Info
  String username = 'Officer';
  String userRole = 'Police';
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAlertHistory();
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      _userId = user.uid; // Store current user ID
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
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }

  void _loadAlertHistory() {
    _database
        .child('alerts')
        .orderByChild('timestamp')
        .limitToLast(100)
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

          // Only show non-active alerts (history)
          String status = alert['status'] ?? 'unknown';
          if (status != 'active' && status != 'pending') {
            // 🎯 IMPORTANT: Only show alerts accepted by current user
            String acceptedBy = alert['acceptedBy'] ?? '';
            String acceptedById = alert['acceptedById'] ?? '';
            if (acceptedBy == _userId || acceptedBy == username || acceptedById == _userId) {
              String weaponType =
                  alert['type'] ?? alert['weapon_class'] ?? 'Unknown';
              double confidence = alert['confidence']?.toDouble() ?? 0.0;
              String location = alert['Area'] ??
                  alert['location']?['address'] ??
                  'Unknown location';

              alert['type'] = weaponType;
              alert['location'] = location;
              alert['time'] = _formatTime(alert['timestamp']);
              alert['resolvedTime'] = alert['acceptedAt'] != null
                  ? _formatDetailedTime(alert['acceptedAt'])
                  : null;

              // Get responder info
              alert['responder'] = (acceptedBy == _userId || acceptedById == _userId) ? username : acceptedBy;

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
          alertHistory = alerts;
          _isLoading = false;
        });
      } else {
        setState(() {
          alertHistory = [];
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

  String _formatDetailedTime(dynamic timeValue) {
    if (timeValue == null) return 'Unknown';

    try {
      DateTime dateTime;
      if (timeValue is String) {
        dateTime = DateTime.parse(timeValue);
      } else if (timeValue is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timeValue);
      } else {
        return 'Unknown';
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  List<Map<String, dynamic>> get _filteredAlerts {
    if (_filterStatus == 'all') return alertHistory;
    return alertHistory
        .where((alert) => alert['status'] == _filterStatus)
        .toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'resolved':
        return Colors.blue;
      case 'dismissed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'resolved':
        return Icons.done_all;
      case 'dismissed':
        return Icons.cancel;
      default:
        return Icons.help_outline;
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
                              'Alert History',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${alertHistory.length} alerts you accepted',
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history,
                              color: Colors.blueAccent,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'HISTORY',
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

                // Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all', Icons.apps),
                        const SizedBox(width: 10),
                        _buildFilterChip(
                            'Accepted', 'accepted', Icons.task_alt),
                        const SizedBox(width: 10),
                        _buildFilterChip(
                            'Resolved', 'resolved', Icons.verified),
                        const SizedBox(width: 10),
                        _buildFilterChip(
                            'Dismissed', 'dismissed', Icons.block),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Alerts List
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.blueAccent,
                          ),
                        )
                      : _filteredAlerts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.manage_history,
                                    size: 80,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'No Accepted Alerts',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'You haven\'t accepted any alerts yet',
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
                              itemCount: _filteredAlerts.length,
                              itemBuilder: (context, index) {
                                final alert = _filteredAlerts[index];
                                return _buildHistoryCard(alert);
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

  Widget _buildFilterChip(String label, String value, IconData icon) {
    bool isSelected = _filterStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(0.4),
                    Colors.blueAccent.withOpacity(0.2),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.blueAccent.withOpacity(0.8)
                : Colors.white.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blueAccent : Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> alert) {
    String status = alert['status'] ?? 'unknown';
    Color statusColor = _getStatusColor(status);
    IconData statusIcon = _getStatusIcon(status);

    String weaponType = alert['type'] ?? 'Unknown';
    String location = alert['location'] ?? 'Unknown';
    String time = alert['time'] ?? 'Just now';
    String responder = alert['responder'] ?? 'Unknown';
    String? resolvedTime = alert['resolvedTime'];

    return Container(
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
          color: statusColor.withOpacity(0.3),
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
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
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
                            'Status: ${status.toUpperCase()}',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withOpacity(0.5),
                        ),
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 16,
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
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Colors.white.withOpacity(0.5),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Occurred: $time',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (resolvedTime != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.emergency,
                        color: statusColor.withOpacity(0.7),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Handled: $resolvedTime',
                        style: TextStyle(
                          color: statusColor.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_circle,
                        color: Colors.blueAccent.withOpacity(0.7),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Responded by: $responder',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
