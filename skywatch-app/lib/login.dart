import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup.dart';
import 'dash.dart';
import 'ambul.dart'; // Import ambulance dashboard
import 'session_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;

  // Controllers for text fields
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _checkSavedCredentials();
  }

  // Check for saved credentials (Remember Me)
  Future<void> _checkSavedCredentials() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool rememberMe = prefs.getBool('rememberMe') ?? false;

      if (rememberMe) {
        String? savedUsername = prefs.getString('savedUsername');
        String? savedPassword = prefs.getString('savedPassword');

        if (savedUsername != null && savedPassword != null) {
          setState(() {
            _usernameController.text = savedUsername;
            _passwordController.text = savedPassword;
            _rememberMe = true;
          });
        }
      }
    } catch (e) {
      print('Error loading saved credentials: $e');
    }
  }

  // Save credentials if Remember Me is checked
  Future<void> _saveCredentials() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('rememberMe', true);
        await prefs.setString('savedUsername', _usernameController.text.trim());
        await prefs.setString('savedPassword', _passwordController.text.trim());
      } else {
        await prefs.remove('rememberMe');
        await prefs.remove('savedUsername');
        await prefs.remove('savedPassword');
      }
    } catch (e) {
      print('Error saving credentials: $e');
    }
  }

  // Navigate based on user role
  void _navigateBasedOnRole(String role) {
    if (role == '1122') {
      // Ambulance dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const AmbulanceDashboardScreen(),
        ),
      );
    } else {
      // Police dashboard (default)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const IovDashboardScreen(),
        ),
      );
    }
  }

  // Login with Firebase using username only
  Future<void> _loginWithFirebase() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String username = _usernameController.text.trim();
      String password = _passwordController.text.trim();

      print('Attempting login with username: $username');

      // Find user by username from Firestore
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _showSnackBar('Username not found', isError: true);
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get user data
      var userData = userQuery.docs.first.data() as Map<String, dynamic>;
      String? email = userData['email'];
      String? uid = userData['uid'];
      String userRole =
          userData['role'] ?? 'Police'; // Get user role, default to Police

      print('Found user with email: $email and role: $userRole');

      if (email == null) {
        _showSnackBar('User email not found', isError: true);
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Sign in with email and password
      try {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        User? user = userCredential.user;

        if (user != null) {
          // Save login session
          await SessionManager.saveLoginSession(
            userId: user.uid,
            username: username,
            role: userRole,
          );

          // Save credentials if Remember Me is checked
          if (_rememberMe) {
            await _saveCredentials();
          }

          // Navigate based on role
          if (mounted) {
            _navigateBasedOnRole(userRole);
          }
        }
      } on FirebaseAuthException catch (e) {
        print('Firebase Auth error: ${e.code} - ${e.message}');

        if (e.code == 'wrong-password') {
          _showSnackBar('Wrong password', isError: true);
        } else if (e.code == 'user-not-found') {
          _showSnackBar('User not found', isError: true);
        } else if (e.code == 'invalid-credential') {
          _showSnackBar('Invalid username or password', isError: true);
        } else {
          _showSnackBar('Login failed: ${e.message}', isError: true);
        }
      }
    } catch (e) {
      print('Unexpected error: $e');
      _showSnackBar('An unexpected error occurred', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Show snackbar message
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Forgot password functionality
  Future<void> _forgotPassword() async {
    String username = _usernameController.text.trim();

    if (username.isEmpty) {
      _showSnackBar('Please enter your username first', isError: true);
      return;
    }

    try {
      // Find user by username
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _showSnackBar('Username not found', isError: true);
        return;
      }

      String email = userQuery.docs.first.get('email');
      await _auth.sendPasswordResetEmail(email: email);

      _showDialog(
        'Password Reset',
        'Password reset email sent to your registered email. Check your inbox.',
      );
    } catch (e) {
      _showSnackBar('Error sending reset email', isError: true);
    }
  }

  // Show dialog
  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(title, style: const TextStyle(color: Colors.blueAccent)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image with Animation
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
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 15),

                      // Logo Section
                      Center(
                        child: TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(seconds: 4),
                          curve: Curves.bounceOut,
                          builder: (context, double value, child) {
                            return Transform.translate(
                              offset: Offset(0, -50 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.blueAccent,
                                      width: 3,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.blueAccent,
                                        blurRadius: 20,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                    image: const DecorationImage(
                                      image: AssetImage('assets/pic.png'),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Login Form - ONLY USERNAME AND PASSWORD
                      Column(
                        children: [
                          // Username Field
                          TextFormField(
                            controller: _usernameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: const TextStyle(color: Colors.white),
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: Colors.white,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Colors.blueAccent,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.3),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter username';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: const TextStyle(color: Colors.white),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Colors.white,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Colors.blueAccent,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.3),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter password';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // Remember Me & Forgot Password
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                                activeColor: Colors.blueAccent,
                                checkColor: Colors.white,
                                side: const BorderSide(color: Colors.white),
                              ),
                              const Text(
                                'Remember Me',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _forgotPassword,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Login Button
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.blueAccent, Colors.lightBlueAccent],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.blueAccent,
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _loginWithFirebase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'SIGN IN',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignUpScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Security Features
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildChip('Theft', Icons.shield),
                          const SizedBox(width: 8),
                          _buildChip('FighNerg', Icons.security),
                          const SizedBox(width: 8),
                          _buildChip('AI', Icons.auto_awesome),
                        ],
                      ),

                      // Version Info
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
}
