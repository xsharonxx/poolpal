import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'phone_verification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userCollection = 'users';
  
  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (result.user != null) {
        // Get user data from Firestore
        final userData = await _firestore
            .collection(_userCollection)
            .doc(result.user!.uid)
            .get();
            
        return UserModel.fromMap({
          'uid': result.user!.uid,
          ...userData.data() ?? {},
        });
      }
      return null;
    } on FirebaseAuthException catch (e) {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // Register with email and password
  Future<UserModel> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required DateTime dateOfBirth,
    required String gender,
    required String race,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final UserModel newUser = UserModel(
        uid: result.user!.uid,
        email: email,
        fullName: fullName,
        phone: phone,
        dateOfBirth: dateOfBirth,
        gender: gender,
        race: race,
        role: 'user', // Default role
        createdAt: DateTime.now(),
        isEmailVerified: false, // Initially false, will be updated when user verifies email
        isPhoneVerified: false,
        isICVerified: false,
        isLicenseVerified: false,
      );

      // Save user data to Firestore
      await _firestore
          .collection(_userCollection)
          .doc(result.user!.uid)
          .set(newUser.toMap());

      return newUser;
    } catch (e) {
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Phone verification methods
  final PhoneVerificationService _phoneVerificationService = PhoneVerificationService();

  Future<void> sendPhoneVerificationCode({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    await _phoneVerificationService.sendVerificationCode(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onError: onError,
    );
  }

  Future<bool> verifyPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    return await _phoneVerificationService.verifyCode(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  Future<void> updatePhoneVerificationStatus(String userId, bool isVerified) async {
    await _phoneVerificationService.updatePhoneVerificationStatus(userId, isVerified);
  }

  Future<bool> getPhoneVerificationStatus(String userId) async {
    return await _phoneVerificationService.getPhoneVerificationStatus(userId);
  }

  // Check if phone number already exists
  Future<bool> isPhoneNumberExists(String phone) async {
    try {
      final querySnapshot = await _firestore
          .collection(_userCollection)
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      rethrow;
    }
  }

  // Check if email is verified
  bool isEmailVerified() {
    return _auth.currentUser?.emailVerified ?? false;
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } catch (e) {
      rethrow;
    }
  }

  // Update email verification status in Firestore
  Future<void> updateEmailVerificationStatus(String userId, bool isVerified) async {
    try {
      await _firestore
          .collection(_userCollection)
          .doc(userId)
          .update({'isEmailVerified': isVerified});
    } catch (e) {
      rethrow;
    }
  }
} 