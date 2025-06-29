import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isLoading = false;
  StreamSubscription<DocumentSnapshot>? _userListener;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.role == 'admin';

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Start listening to user document changes
  void _startUserListener(String userId) {
    _userListener?.cancel();
    _userListener = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        _user = UserModel.fromMap({
          'uid': userId,
          ...snapshot.data() ?? {},
        });
        
        // Check if email verification status needs to be updated
        final isEmailVerified = _authService.isEmailVerified();
        if (isEmailVerified != (_user!.isEmailVerified ?? false)) {
          await updateEmailVerificationStatus(_user!.uid, isEmailVerified);
        }
        
        notifyListeners();
      }
    });
  }

  // Load user data by email (for phone verification scenario)
  Future<void> loadUserByEmail(String email) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first;
        _user = UserModel.fromMap({
          'uid': userData.id,
          ...userData.data(),
        });
        _startUserListener(userData.id);
        notifyListeners();
      }
    } catch (e) {
      print('Error loading user by email: $e');
    }
  }

  // Stop listening to user document changes
  void _stopUserListener() {
    _userListener?.cancel();
    _userListener = null;
  }

  Future<void> signIn(String email, String password) async {
    try {
      _setLoading(true);
      _user = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );
      if (_user != null) {
        _startUserListener(_user!.uid);
        
        // Check if email verification status needs to be updated
        final isEmailVerified = _authService.isEmailVerified();
        if (isEmailVerified != (_user!.isEmailVerified ?? false)) {
          await updateEmailVerificationStatus(_user!.uid, isEmailVerified);
        }
      }
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> isPhoneNumberExists(String phone) async {
    try {
      return await _authService.isPhoneNumberExists(phone);
    } catch (e) {
      print('Error checking phone number existence: $e');
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required DateTime dateOfBirth,
    required String gender,
    required String race,
  }) async {
    try {
      _setLoading(true);
      _user = await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        dateOfBirth: dateOfBirth,
        gender: gender,
        race: race,
      );
      if (_user != null) {
        _startUserListener(_user!.uid);
      }
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      _setLoading(true);
      await _authService.resetPassword(email);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    try {
      _setLoading(true);
      await _authService.signOut();
      _stopUserListener();
      _user = null;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void setUser(UserModel user) {
    _user = user;
    _startUserListener(user.uid);
    notifyListeners();
  }

  Future<void> loadUserFromFirebase() async {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser != null) {
      _startUserListener(firebaseUser.uid);
    }
  }

  // Email verification methods
  bool isEmailVerified() {
    return _authService.isEmailVerified();
  }

  Future<void> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
    } catch (e) {
      print('Error sending email verification: $e');
      rethrow;
    }
  }

  Future<void> updateEmailVerificationStatus(String userId, bool isVerified) async {
    try {
      await _authService.updateEmailVerificationStatus(userId, isVerified);
    } catch (e) {
      print('Error updating email verification status: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _stopUserListener();
    super.dispose();
  }
} 