import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // User data
  String fullName = '';
  String username = '';
  String email = '';
  String phone = '';
  String role = '';
  String carNumber = '';
  String _userId = '';
  bool isLoading = true;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();

    _loadUserData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      _userId = user.uid; // Store user ID
      try {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          
          // Debug: Print all user data
          print('🔍 User Data from Firestore: $userData');
          print('🚗 Vehicle Number: ${userData['vehicleNumber']}');
          print('🚑 Ambulance Number: ${userData['ambulanceNumber']}');
          print('🚓 Car Number: ${userData['carNumber']}');
          
          setState(() {
            fullName = userData['fullName'] ?? 'N/A';
            username = userData['username'] ?? 'N/A';
            email = userData['email'] ?? user.email ?? 'N/A';
            phone = userData['phone'] ?? 'N/A';
            role = userData['role'] ?? 'N/A';
            carNumber =
                userData['vehicleNumber'] ?? 
                userData['ambulanceNumber'] ?? 
                userData['carNumber'] ?? 'N/A';
            
            // Debug: Print final carNumber value
            print('✅ Final Car Number: $carNumber');
            isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading profile: $e');
        setState(() => isLoading = false);
      }
    }
  }

  // 🔥 UPDATED: Set IOV offline in Firebase Realtime Database
  Future<void> _setIovOffline() async {
    if (_userId.isEmpty) return;

    try {
      await _database.child('iovs/$_userId').update({
        'isOnline': false,
        'status': 'offline',
        'lastUpdate': ServerValue.timestamp,
        'lastSeen': DateTime.now().toIso8601String(),
        'loggedOutAt': DateTime.now().toIso8601String(),
        'logoutTime': DateTime.now().toIso8601String(),
        'lastLogout': ServerValue.timestamp,
      });
      print('✅ IOV status updated to OFFLINE for user: $_userId');
    } catch (e) {
      print('❌ Error setting IOV offline: $e');
    }
  }

  // 🔥 UPDATED: Logout function with offline status
  Future<void> _logout() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      ),
    );

    try {
      // Step 1: Set IOV status to OFFLINE in Realtime Database
      await _setIovOffline();

      // Step 2: Sign out from Firebase Auth
      await _auth.signOut();

      // Step 3: Navigate to login screen
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      print('❌ Logout error: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated Background (same as dashboard)
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
          child: isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.blueAccent),
                      SizedBox(height: 20),
                      Text(
                        'Loading profile...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        // Profile Header with Slide Animation
                        SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.blueAccent.withOpacity(0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Profile Picture with Animation
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.blueAccent,
                                      width: 3,
                                    ),
                                    gradient: const RadialGradient(
                                      colors: [
                                        Colors.blueAccent,
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: Container(
                                      color: Colors.blueAccent.withOpacity(0.1),
                                      child: const Icon(
                                        Icons.person,
                                        size: 45,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Name with Animation
                                TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 0.8, end: 1.0),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.elasticOut,
                                  builder: (context, double scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: Column(
                                        children: [
                                          Text(
                                            fullName,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.blueAccent
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            child: Text(
                                              '@$username',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.blueAccent,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Info Cards with Staggered Animation
                        _buildAnimatedInfoCard(
                          index: 0,
                          icon: Icons.email,
                          label: 'Email',
                          value: email,
                          color: Colors.blue,
                        ),
                        _buildAnimatedInfoCard(
                          index: 1,
                          icon: Icons.phone,
                          label: 'Phone',
                          value: phone,
                          color: Colors.blue,
                        ),
                        _buildAnimatedInfoCard(
                          index: 2,
                          icon: role == 'Police'
                              ? Icons.local_police
                              : Icons.emergency,
                          label: 'Role',
                          value: role,
                          color: role == 'Police' ? Colors.blue : Colors.blue,
                        ),
                        _buildAnimatedInfoCard(
                          index: 3,
                          icon: role == 'Police'
                              ? Icons.directions_car
                              : Icons.local_hospital,
                          label:
                              role == 'Police' ? 'Car Number' : 'Ambulance No.',
                          value: carNumber,
                          color: role == 'Police' ? Colors.blue : Colors.red,
                        ),

                        const SizedBox(height: 30),

                        // Online Status Indicator (for visual feedback)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Colors.green, size: 10),
                              SizedBox(width: 6),
                              Text(
                                'Currently Online',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Logout Button with Animation
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0.9, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                          builder: (context, double scale, child) {
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: double.infinity,
                                height: 55,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF4B4B),
                                      Color(0xFFFF6B6B),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.3),
                                      blurRadius: 15,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _logout,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.logout, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        'LOGOUT',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // Info: What happens on logout
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blueAccent.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blueAccent.withOpacity(0.5),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Logging out will mark your vehicle as OFFLINE in the system',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Version Info
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.2),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAnimatedInfoCard({
    required int index,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, double opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - opacity)),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
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
}
