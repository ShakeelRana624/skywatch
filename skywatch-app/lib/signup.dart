import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeTerms = false;
  bool _showMoreInfo = false;
  bool _isLoading = false;
  String? _selectedRole;

  // Controllers for form fields
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Additional professional fields controllers
  final TextEditingController _rankController = TextEditingController();
  final TextEditingController _policeStationController =
      TextEditingController();
  final TextEditingController _carNumberController = TextEditingController();
  final TextEditingController _carColorController = TextEditingController();
  final TextEditingController _carModelController = TextEditingController();
  final TextEditingController _ambulanceNumberController = TextEditingController();
  final TextEditingController _ambulanceTypeController = TextEditingController();

  // Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final List<String> _roles = ['Police', '1122'];

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up with Firebase
  Future<void> _signUpWithFirebase() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreeTerms) {
      _showSnackBar('Please agree to terms and conditions', isError: true);
      return;
    }

    if (_selectedRole == null) {
      _showSnackBar('Please select your role', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String email = _emailController.text.trim();
      String password = _passwordController.text.trim();
      String username = _usernameController.text.trim();
      String fullName = _fullNameController.text.trim();
      String phone = _phoneController.text.trim();

      print('Starting signup process...');
      print('Email: $email');
      print('Username: $username');

      // Check if username already exists
      try {
        QuerySnapshot usernameCheck = await _firestore
            .collection('users')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();

        if (usernameCheck.docs.isNotEmpty) {
          _showSnackBar('Username already taken', isError: true);
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        print('Error checking username: $e');
        // Continue anyway - maybe Firestore rules not set
      }

      // Create user with Firebase Auth
      UserCredential userCredential;
      try {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('User created successfully');
      } catch (e) {
        print('Auth error: $e');
        if (e is FirebaseAuthException) {
          if (e.code == 'email-already-in-use') {
            _showSnackBar('Email already registered', isError: true);
          } else if (e.code == 'invalid-email') {
            _showSnackBar('Invalid email address', isError: true);
          } else if (e.code == 'weak-password') {
            _showSnackBar('Password too weak', isError: true);
          } else {
            _showSnackBar('Auth error: ${e.message}', isError: true);
          }
        } else {
          _showSnackBar('Authentication failed', isError: true);
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      User? user = userCredential.user;

      if (user != null) {
        try {
          // Update display name
          await user.updateDisplayName(fullName);
          await user.reload();
          print('Display name updated');

          // Prepare user data for Firestore
          Map<String, dynamic> userData = {
            'uid': user.uid,
            'fullName': fullName,
            'username': username,
            'email': email,
            'phone': phone,
            'role': _selectedRole,
            'createdAt': FieldValue.serverTimestamp(),
            'isActive': true,
            'emailVerified': user.emailVerified,
          };

          // Add professional info for Police
          if (_selectedRole == 'Police' && _showMoreInfo) {
            userData.addAll({
              'rank': _rankController.text.trim(),
              'policeStation': _policeStationController.text.trim(),
              'carNumber': _carNumberController.text.trim(),
              'carColor': _carColorController.text.trim(),
              'carModel': _carModelController.text.trim(),
              'isAvailable': true,
            });
          }

          // Add 1122 specific fields
          if (_selectedRole == '1122' && _showMoreInfo) {
            userData.addAll({
              'ambulanceNumber': _ambulanceNumberController.text.trim(),
              'ambulanceType': _ambulanceTypeController.text.trim(),
              'isAvailable': true,
            });
          }

          // Save user data to Firestore
          try {
            await _firestore.collection('users').doc(user.uid).set(userData);
            print('User data saved to Firestore');
          } catch (e) {
            print('Firestore error: $e');
            // Firestore save failed but auth succeeded
            _showSnackBar(
              'Account created but profile save failed',
              isError: true,
            );
          }

          // Send email verification
          try {
            await user.sendEmailVerification();
            print('Verification email sent');
          } catch (e) {
            print('Verification email error: $e');
          }

          // Show success message
          _showSuccessDialog();
        } catch (e) {
          print('Post-auth error: $e');
          _showSnackBar('Account created but error in setup', isError: true);
          // Still navigate to login
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        }
      }
    } catch (e) {
      print('Unexpected error: $e');
      _showSnackBar('An unexpected error occurred: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Show success dialog
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Icon(
          Icons.check_circle_outline,
          color: Colors.green,
          size: 60,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Account Created Successfully!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'A verification email has been sent to\n${_emailController.text}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 5),
            const Text(
              'Please verify your email before logging in.',
              style: TextStyle(color: Colors.blueAccent, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.blueAccent, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // Show snackbar
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),

                      // Logo Section
                      Center(
                        child: TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(seconds: 3),
                          curve: Curves.elasticOut,
                          builder: (context, double value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.blueAccent,
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.blueAccent,
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                  image: const DecorationImage(
                                    image: AssetImage('assets/pic.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Welcome Text
                      const Center(
                        child: Text(
                          'Join us to protect',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                            letterSpacing: 1,
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // IOV Role Dropdown
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.black.withOpacity(0.3),
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          dropdownColor: Colors.black87,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Select IOV Role',
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.badge_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.white,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.blueAccent,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 15,
                            ),
                          ),
                          items: _roles.map((String role) {
                            return DropdownMenuItem<String>(
                              value: role,
                              child: Row(
                                children: [
                                  Icon(
                                    role == 'Police'
                                        ? Icons.local_police
                                        : Icons.emergency,
                                    color: Colors.blueAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    role,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedRole = newValue;
                              _showMoreInfo = false;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select your role';
                            }
                            return null;
                          },
                        ),
                      ),
                      // Sign Up Form
                      const SizedBox(height: 10),

                      Column(
                        children: [
                          // Full Name Field
                          TextFormField(
                            controller: _fullNameController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              labelStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.blueAccent,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.3),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 15,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter full name';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          // Username Field
                          TextFormField(
                            controller: _usernameController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.alternate_email,
                                color: Colors.white,
                                size: 20,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.blueAccent,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.3),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 15,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter username';
                              }
                              if (value.length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              labelStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.blueAccent,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.3),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 15,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter email';
                              }
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          const SizedBox(height: 12),

                          // Phone Number Field
                          TextFormField(
                            controller: _phoneController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              labelStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.phone_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.blueAccent,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.3),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 15,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter phone number';
                              }
                              if (value.length < 10) {
                                return 'Enter valid phone number';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.blueAccent,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.3),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 15,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          // Confirm Password Field
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: !_isConfirmPasswordVisible,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              labelStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isConfirmPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isConfirmPasswordVisible =
                                        !_isConfirmPasswordVisible;
                                  });
                                },
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.blueAccent,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.3),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 15,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // More Info Toggle Button
                      if (_selectedRole == 'Police' || _selectedRole == '1122')
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showMoreInfo = !_showMoreInfo;
                              });
                            },
                            icon: Icon(
                              _showMoreInfo
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.blueAccent,
                            ),
                            label: Text(
                              _showMoreInfo
                                  ? 'Hide Professional Info'
                                  : 'Add Professional Info',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // More Info Section (Professional Details)
                      if (_showMoreInfo && _selectedRole == 'Police')
                        Column(
                          children: [
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.blueAccent.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Rank Field
                                  TextFormField(
                                    controller: _rankController,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Rank',
                                      labelStyle: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.stars_outlined,
                                        color: Colors.blueAccent,
                                        size: 18,
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Police Station Area
                                  TextFormField(
                                    controller: _policeStationController,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Police Station Area',
                                      labelStyle: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.location_on_outlined,
                                        color: Colors.blueAccent,
                                        size: 18,
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Police Car Number
                                  TextFormField(
                                    controller: _carNumberController,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Police Car Number',
                                      labelStyle: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.directions_car_outlined,
                                        color: Colors.blueAccent,
                                        size: 18,
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Car Color
                                  TextFormField(
                                    controller: _carColorController,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Car Color',
                                      labelStyle: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.color_lens_outlined,
                                        color: Colors.blueAccent,
                                        size: 18,
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Car Model
                                  TextFormField(
                                    controller: _carModelController,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Car Model',
                                      labelStyle: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.model_training,
                                        color: Colors.blueAccent,
                                        size: 18,
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                      // More Info Section (Professional Details for 1122)
                      if (_showMoreInfo && _selectedRole == '1122')
                        Column(
                          children: [
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Ambulance Number Field
                                  TextFormField(
                                    controller: _ambulanceNumberController,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Ambulance Number',
                                      labelStyle: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.local_hospital_outlined,
                                        color: Colors.redAccent,
                                        size: 18,
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter ambulance number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // Ambulance Type Field
                                  TextFormField(
                                    controller: _ambulanceTypeController,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Ambulance Type (e.g. Basic Life Support, Advanced)',
                                      labelStyle: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.medical_services_outlined,
                                        color: Colors.redAccent,
                                        size: 18,
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 15),

                      // Terms and Conditions
                      Row(
                        children: [
                          Checkbox(
                            value: _agreeTerms,
                            onChanged: (value) {
                              setState(() {
                                _agreeTerms = value ?? false;
                              });
                            },
                            activeColor: Colors.blueAccent,
                            checkColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms',
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy',
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // Sign Up Button
                      Container(
                        width: double.infinity,
                        height: 45,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.blueAccent, Colors.lightBlueAccent],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.blueAccent,
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signUpWithFirebase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                                  'CREATE ACCOUNT',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Sign In Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 30),
                            ),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Security Features
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildChip('Theft', Icons.shield),
                          const SizedBox(width: 6),
                          _buildChip('FighNerg', Icons.security),
                          const SizedBox(width: 6),
                          _buildChip('AI', Icons.auto_awesome),
                        ],
                      ),
                      const SizedBox(height: 10),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 10),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _rankController.dispose();
    _policeStationController.dispose();
    _carNumberController.dispose();
    _carColorController.dispose();
    _carModelController.dispose();
    _ambulanceNumberController.dispose();
    _ambulanceTypeController.dispose();
    super.dispose();
  }
}
