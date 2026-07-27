import 'package:flutter/material.dart';

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'login.dart';

import 'dash.dart';

import 'ambul.dart';

import 'firebase_options.dart';
import 'session_manager.dart';



void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first

  try {

    await Firebase.initializeApp(

      options: DefaultFirebaseOptions.currentPlatform,

    );

    print('Firebase initialized successfully');

  } catch (e) {

    print('Firebase initialization error: $e');

  }

  // Enable Firebase Auth persistence after Firebase is initialized
  try {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    print('Firebase Auth persistence enabled');
  } catch (e) {
    print('Firebase Auth persistence error: $e');
  }
  
  // Initialize session from Firebase
  try {
    await SessionManager.initializeFromFirebase();
    print('SessionManager initialized');
  } catch (e) {
    print('SessionManager initialization error: $e');
  }

  runApp(const MyApp());

}



class MyApp extends StatelessWidget {

  const MyApp({super.key});



  @override

  Widget build(BuildContext context) {

    return MaterialApp(

      title: 'Smart Surveillance & IoV',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(

        primarySwatch: Colors.red,

        fontFamily: 'Poppins',

        scaffoldBackgroundColor: Colors.black,

        brightness: Brightness.dark,

      ),

      home: const SplashScreen(),

    );

  }

}



class SplashScreen extends StatefulWidget {

  const SplashScreen({super.key});



  @override

  State<SplashScreen> createState() => _SplashScreenState();

}



class _SplashScreenState extends State<SplashScreen>

    with TickerProviderStateMixin {

  late AnimationController _controller;

  late Animation<double> _scaleAnimation;

  late Animation<double> _opacityAnimation;



  StreamSubscription<User?>? _authSubscription;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;



  bool _hasNavigated = false;



  @override

  void initState() {

    super.initState();



    // Initialize animations

    _controller = AnimationController(

      duration: const Duration(seconds: 3),

      vsync: this,

    );



    _scaleAnimation = Tween<double>(

      begin: 1.3,

      end: 1.0,

    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));



    _opacityAnimation = Tween<double>(

      begin: 0.0,

      end: 1.0,

    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInQuad));



    _controller.forward();



    // Wait for Firebase Auth to restore session, then check auth state

    _waitForAuthAndNavigate();

  }



  // Wait for Firebase Auth to restore session properly

  Future<void> _waitForAuthAndNavigate() async {

    print('=== Starting session restoration ===');

    // Give Firebase Auth more time to restore persisted session in web mode

    await Future.delayed(const Duration(seconds: 2));

    print('Delay completed, checking session...');



    // Check if user is logged in via SessionManager (SharedPreferences)

    bool isLoggedIn = await SessionManager.isLoggedIn();

    print('SessionManager isLoggedIn: $isLoggedIn');

    User? currentUser = _auth.currentUser;

    print('Firebase Auth currentUser: ${currentUser?.uid}');



    if (isLoggedIn) {

      print('SessionManager says user is logged in, proceeding...');

      // If SessionManager says logged in, wait for Firebase Auth to catch up

      if (currentUser == null) {

        print('Firebase Auth user is null, waiting more...');

        // Wait a bit more for Firebase Auth to restore

        await Future.delayed(const Duration(seconds: 1));

        currentUser = _auth.currentUser;

        print('Firebase Auth currentUser after delay: ${currentUser?.uid}');

      }

      

      if (currentUser != null) {

        print('Both SessionManager and Firebase Auth agree, navigating to dashboard...');

        // User session restored, navigate to dashboard

        _checkUserAndNavigate(currentUser);

      } else {

        print('SessionManager says logged in but Firebase Auth is null, using SessionManager data...');

        // SessionManager says logged in but Firebase Auth doesn't, use SessionManager data

        String? userRole = await SessionManager.getUserRole();

        print('Using SessionManager data: role=$userRole');

        _navigateBasedOnRole(userRole ?? 'Police');

      }

    } else {

      print('SessionManager says user is not logged in, listening for auth changes...');

      // No persisted session, listen for auth changes

      _authSubscription = _auth.authStateChanges().listen((User? user) {

        print('Auth state changed: user=${user?.uid}');

        if (!_hasNavigated) {

          _checkUserAndNavigate(user);

        }

      });

    }

  }



  Future<void> _checkUserAndNavigate(User? user) async {

    if (_hasNavigated) return;

    print('Checking user and navigating: user=${user?.uid}');



    if (user != null) {

      // User is logged in, get role from SessionManager first (faster)

      try {

        String? userRole = await SessionManager.getUserRole();

        print('User role from SessionManager: $userRole');

        _hasNavigated = true;

        // Navigate based on role

        if (userRole == '1122') {

          _navigateTo(const AmbulanceDashboardScreen());

        } else {

          _navigateTo(const IovDashboardScreen());

        }

      } catch (e) {

        print('Error getting user role from SessionManager: $e');

        // Fallback to Firestore

        try {

          DocumentSnapshot userDoc = await _firestore

              .collection('users')

              .doc(user.uid)

              .get();



          if (userDoc.exists) {

            String userRole = userDoc.get('role') ?? 'Police';

            _hasNavigated = true;

            print('User role from Firestore: $userRole');

            // Navigate based on role

            if (userRole == '1122') {

              _navigateTo(const AmbulanceDashboardScreen());

            } else {

              _navigateTo(const IovDashboardScreen());

            }

          } else {

            // User doc not found, go to login

            _hasNavigated = true;

            print('User doc not found, going to login');

            _navigateTo(const LoginScreen());

          }

        } catch (e) {

          print('Error fetching user role from Firestore: $e');

          _hasNavigated = true;

          // Default to police dashboard if error

          _navigateTo(const IovDashboardScreen());

        }

      }

    } else {

      // No user logged in, go to login

      _hasNavigated = true;

      print('No user logged in, going to login');

      _navigateTo(const LoginScreen());

    }

  }



  void _navigateTo(Widget screen) {

    // Wait for animation to complete before navigating

    Future.delayed(const Duration(seconds: 6), () {

      if (mounted) {

        Navigator.of(

          context,

        ).pushReplacement(MaterialPageRoute(builder: (context) => screen));

      }

    });

  }

  void _navigateBasedOnRole(String userRole) {

    _hasNavigated = true;

    if (userRole == '1122') {

      _navigateTo(const AmbulanceDashboardScreen());

    } else {

      _navigateTo(const IovDashboardScreen());

    }

  }



  @override

  void dispose() {

    _authSubscription?.cancel();

    _controller.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.black,

      body: Stack(

        children: [

          // Animated Background Image

          AnimatedBuilder(

            animation: _controller,

            builder: (context, child) {

              return Opacity(

                opacity: _opacityAnimation.value,

                child: Transform.scale(

                  scale: _scaleAnimation.value,

                  child: Container(

                    width: double.infinity,

                    height: double.infinity,

                    decoration: const BoxDecoration(

                      image: DecorationImage(

                        image: AssetImage('assets/pic.png'),

                        fit: BoxFit.cover,

                      ),

                    ),

                  ),

                ),

              );

            },

          ),



          // Dark Overlay for better text visibility

        ],

      ),

    );

  }

}

