 import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final String _rememberMeKey = 'remember_me';
  static final String _savedEmailKey = 'saved_email';

  // Get Firebase Database reference with correct URL
  static DatabaseReference _getDatabaseReference() {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://tamkeened-8821e-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref();
  }

  // Initialize Firebase
  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      // Firebase is already initialized, which is fine
      if (e.toString().contains('duplicate-app')) {
        print('Firebase already initialized');
      } else {
        // Re-throw if it's a different error
        rethrow;
      }
    }
  }

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Check if user is signed in
  static bool get isSignedIn => _auth.currentUser != null;

  // Auth state changes stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  static Future<AuthResult> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    try {
      print('🚀 Starting signup process...');
      print('📧 Email: $email');
      print('👤 Name: $firstName $lastName');
      
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Firebase Auth user created successfully');
      print('🔑 UID: ${userCredential.user?.uid}');

      // Update display name
      await userCredential.user?.updateDisplayName('$firstName $lastName');
      print('✅ Display name updated');

      // Save user profile to Realtime Database
      if (userCredential.user != null) {
        print('💾 Calling _saveUserProfile...');
        await _saveUserProfile(
          userCredential.user!.uid,
          firstName,
          lastName,
          email,
          phoneNumber,
        );
        print('✅ _saveUserProfile completed');
      } else {
        print('❌ User is null, cannot save profile');
      }

      // Send email verification
      await userCredential.user?.sendEmailVerification();
      print('📧 Email verification sent');

      return AuthResult(
        success: true,
        user: userCredential.user,
        message: 'Account created successfully! Please check your email for verification.',
      );
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      return AuthResult(
        success: false,
        message: _getErrorMessage(e.code),
      );
    } catch (e) {
      print('❌ General exception during signup: $e');
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  // Sign in with email and password
  static Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Handle remember me functionality
      await _handleRememberMe(email, rememberMe);

      return AuthResult(
        success: true,
        user: userCredential.user,
        message: 'Signed in successfully!',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getErrorMessage(e.code),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  // Send password reset email
  static Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult(
        success: true,
        message: 'Password reset email sent successfully!',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getErrorMessage(e.code),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  // Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
    await _clearRememberedCredentials();
  }

  // Remember me functionality
  static Future<void> _handleRememberMe(String email, bool rememberMe) async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setBool(_rememberMeKey, true);
      await prefs.setString(_savedEmailKey, email);
    } else {
      await prefs.remove(_rememberMeKey);
      await prefs.remove(_savedEmailKey);
    }
  }

  // Get remembered email
  static Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_rememberMeKey) ?? false;
    if (rememberMe) {
      return prefs.getString(_savedEmailKey);
    }
    return null;
  }

  // Check if remember me is enabled
  static Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  // Clear remembered credentials
  static Future<void> _clearRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_savedEmailKey);
  }

  // Save user profile to Realtime Database
  static Future<void> _saveUserProfile(
    String uid,
    String firstName,
    String lastName,
    String email,
    String? phoneNumber,
  ) async {
    try {
      print('🔄 Attempting to save user profile for UID: $uid');
      print('📧 Email: $email');
      print('👤 Name: $firstName $lastName');
      print('📱 Phone: ${phoneNumber ?? "Not provided"}');
      
      final dbRef = _getDatabaseReference();
      
      final profileData = {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'createdAt': DateTime.now().toIso8601String(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        profileData['phoneNumber'] = phoneNumber;
      }
      
      print('💾 Profile data to save: $profileData');
      
      await dbRef.child('users').child(uid).set(profileData);
      
      print('✅ User profile saved successfully!');
    } catch (e) {
      // Log error but don't throw to avoid breaking signup flow
      print('❌ Error saving user profile: $e');
      print('📍 Stack trace: ${StackTrace.current}');
    }
  }

  // Get user profile from Realtime Database
  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final dbRef = _getDatabaseReference();
      final snapshot = await dbRef.child('users').child(uid).get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile in Realtime Database
  static Future<bool> updateUserProfile(
    String uid,
    Map<String, dynamic> profileData,
  ) async {
    try {
      final dbRef = _getDatabaseReference();
      profileData['lastUpdated'] = DateTime.now().toIso8601String();
      await dbRef.child('users').child(uid).update(profileData);
      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  // Get error message for Firebase Auth exceptions
  static String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'invalid-credential':
        return 'The supplied auth credential is incorrect or has expired.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}

// Result class for authentication operations
class AuthResult {
  final bool success;
  final User? user;
  final String message;

  AuthResult({
    required this.success,
    this.user,
    required this.message,
  });
}