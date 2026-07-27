import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyUserRole = 'userRole';
  static const String _keyUsername = 'username';
  static const String _keyUserId = 'userId';

  // Save login session
  static Future<void> saveLoginSession({
    required String userId,
    required String username,
    required String role,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUserId, userId);
      await prefs.setString(_keyUsername, username);
      await prefs.setString(_keyUserRole, role);
      print('✅ Login session saved for user: $username');
    } catch (e) {
      print('❌ Error saving login session: $e');
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsLoggedIn) ?? false;
    } catch (e) {
      print('❌ Error checking login status: $e');
      return false;
    }
  }

  // Get user role
  static Future<String> getUserRole() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserRole) ?? 'Police';
    } catch (e) {
      print('❌ Error getting user role: $e');
      return 'Police';
    }
  }

  // Get username
  static Future<String> getUsername() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUsername) ?? 'User';
    } catch (e) {
      print('❌ Error getting username: $e');
      return 'User';
    }
  }

  // Get user ID
  static Future<String> getUserId() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserId) ?? '';
    } catch (e) {
      print('❌ Error getting user ID: $e');
      return '';
    }
  }

  // Clear login session (logout)
  static Future<void> clearSession() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyUserRole);
      print('✅ Login session cleared');
    } catch (e) {
      print('❌ Error clearing login session: $e');
    }
  }

  // Initialize session from Firebase Auth
  static Future<void> initializeFromFirebase() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Get user data from Firestore to set session
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;
          String username = userData['username'] ?? userData['fullName'] ?? 'User';
          String userRole = userData['role'] ?? 'Police';
          String userId = currentUser.uid;
          
          // Save session to SharedPreferences
          await saveLoginSession(
            userId: userId,
            username: username,
            role: userRole,
          );
          
          print('✅ Firebase session initialized: $username ($userRole)');
        } else {
          print('❌ User document not found for UID: ${currentUser.uid}');
        }
      } else {
        print('ℹ️ No Firebase user found');
      }
    } catch (e) {
      print('❌ Error initializing session from Firebase: $e');
    }
  }
}
