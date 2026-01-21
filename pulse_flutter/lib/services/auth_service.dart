import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _user;
  bool _isLoading = true;
  String? _errorMessage;
  bool _googleSignInInitialized = false;

  User? get currentUser => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isLoading = false;
      notifyListeners();
    });
  }

  // Initialize Google Sign In (must be called once before using)
  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleSignInInitialized = true;
    }
  }

  Future<void> refreshAuthToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.getIdToken(true);
    }
  }

  // Email & Password Sign Up
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        await result.user!.updateDisplayName(displayName);
        await _createUserProfile(result.user!, 'email', displayName);
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e.code));
      return false;
    } catch (e) {
      _setError('An unexpected error occurred');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Email & Password Sign In
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        await _updateUserProfile(result.user!, 'email');
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e.code));
      return false;
    } catch (e) {
      _setError('An unexpected error occurred');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Google Sign In (updated for google_sign_in 7.x)
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      _clearError();

      // Initialize Google Sign In
      await _ensureGoogleSignInInitialized();

      // Authenticate with Google
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: ['email', 'profile'],
      );
      
      if (googleUser == null) {
        _setLoading(false);
        return false; // User cancelled
      }

      // Get ID token from authentication (synchronous in v7)
      final String? idToken = googleUser.authentication.idToken;

      // Get authorization with scopes to obtain access token
      final authorization = await googleUser.authorizationClient.authorizeScopes(
        ['email', 'profile'],
      );

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: authorization.accessToken,
        idToken: idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(credential);
      
      if (result.user != null) {
        await _createUserProfile(result.user!, 'google');
        return true;
      }
      return false;
    } on GoogleSignInException catch (e) {
      _setError('Google sign in failed: ${e.description ?? e.code.name}');
      return false;
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e.code));
      return false;
    } catch (e) {
      _setError('Google sign in failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Password Reset
  Future<bool> resetPassword(String email) async {
    try {
      _setLoading(true);
      _clearError();

      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e.code));
      return false;
    } catch (e) {
      _setError('Failed to send password reset email');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _ensureGoogleSignInInitialized();
      await GoogleSignIn.instance.disconnect();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  // Create user profile in Firestore
  Future<void> _createUserProfile(User user, String loginMethod, [String? displayName]) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'userId': user.uid,
          'email': user.email,
          'displayName': displayName ?? user.displayName,
          'loginMethod': loginMethod,
          'createdAt': FieldValue.serverTimestamp(),
          'isProfileComplete': displayName != null,
          'preferences': {
            'notifications': true,
            'maxDistance': 10.0,
            'categories': ['restaurant', 'cafe', 'shop', 'activity'],
          },
          'favoriteDeals': {},
          'location': {},
        });
      }
    } catch (e) {
      debugPrint('Error creating user profile: $e');
    }
  }

  // Update existing user profile
  Future<void> _updateUserProfile(User user, String loginMethod) async {
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'loginMethod': loginMethod,
      });
    } catch (e) {
      debugPrint('Error updating user profile: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'user-not-found':
        return 'No user found for this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}