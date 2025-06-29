import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PhoneVerificationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Simple verification code storage (in production, this would be in a database)
  static final Map<String, String> _verificationCodes = {};
  static final Map<String, DateTime> _codeTimestamps = {};
  
  // Send verification code to phone number (Firebase with manual control)
  Future<void> sendVerificationCode({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    try {
      String formattedPhone = phoneNumber.startsWith('+') ? phoneNumber : '+$phoneNumber';

      // Use Firebase phone verification with manual control
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) {
          // ⚠️ Do NOT call signInWithCredential() here
          // Instead, we'll handle verification manually
          print('Auto-verification completed, but we\'ll handle it manually');
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Handle timeout
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      onError(e.toString());
    }
  }
  
  // Generate a 6-digit verification code (for simple verification)
  String _generateVerificationCode() {
    return (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
  }
  
  // Send verification code using simple method (alternative)
  Future<void> sendSimpleVerificationCode({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    try {
      String formattedPhone = phoneNumber.startsWith('+') ? phoneNumber : '+$phoneNumber';
      
      // Generate a 6-digit verification code
      String verificationCode = _generateVerificationCode();
      
      // Store the code with timestamp
      _verificationCodes[formattedPhone] = verificationCode;
      _codeTimestamps[formattedPhone] = DateTime.now();
      
      print('=== SIMULATED SMS VERIFICATION ===');
      print('Phone: $formattedPhone');
      print('Verification Code: $verificationCode');
      print('=== END SIMULATED SMS ===');
      
      // In a real app, you would send this code via SMS
      // For now, we'll just simulate it
      onCodeSent(formattedPhone); // Pass phone as verificationId
    } catch (e) {
      onError(e.toString());
    }
  }
  
  // Verify the SMS code without signing in
  Future<bool> verifyCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      print('Verifying OTP without signing in user');
      
      // Create credential but don't sign in
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      // ✅ Instead of signing in, just check if it's valid by linking with current user
      // This will throw an error if the OTP is invalid
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        try {
          await currentUser.linkWithCredential(credential);
          print('OTP verification successful - phone linked to current user');
          return true;
        } catch (e) {
          print('OTP verification failed: $e');
          return false;
        }
      } else {
        // If no current user, we can't link, so just verify the credential is valid
        // by trying to sign in temporarily and then sign out
        try {
          await _auth.signInWithCredential(credential);
          // If we get here, the OTP was valid
          await _auth.signOut(); // Sign out immediately
          print('OTP verification successful - credential is valid');
          return true;
        } catch (e) {
          print('OTP verification failed: $e');
          return false;
        }
      }
    } catch (e) {
      print('Error during OTP verification: $e');
      return false;
    }
  }
  
  // Verify the SMS code (simple verification)
  Future<bool> verifySimpleCode({
    required String verificationId, // This will be the phone number
    required String smsCode,
  }) async {
    try {
      String phoneNumber = verificationId;
      
      // Check if code exists and is not expired
      if (!_verificationCodes.containsKey(phoneNumber)) {
        print('No verification code found for phone: $phoneNumber');
        return false;
      }
      
      String storedCode = _verificationCodes[phoneNumber]!;
      DateTime? timestamp = _codeTimestamps[phoneNumber];
      
      // Check if code is expired (5 minutes)
      if (timestamp != null && DateTime.now().difference(timestamp).inMinutes > 5) {
        print('Verification code expired for phone: $phoneNumber');
        _verificationCodes.remove(phoneNumber);
        _codeTimestamps.remove(phoneNumber);
        return false;
      }
      
      // Check if code matches
      if (storedCode == smsCode) {
        print('Verification code matched for phone: $phoneNumber');
        // Clean up the used code
        _verificationCodes.remove(phoneNumber);
        _codeTimestamps.remove(phoneNumber);
        return true;
      } else {
        print('Verification code mismatch for phone: $phoneNumber');
        print('Expected: $storedCode, Received: $smsCode');
        return false;
      }
    } catch (e) {
      print('Error during code verification: $e');
      return false;
    }
  }

  // Update phone verification status in Firestore
  Future<void> updatePhoneVerificationStatus(String userId, bool isVerified) async {
    try {
      print('=== PHONE VERIFICATION UPDATE DEBUG ===');
      print('Updating phone verification status for user: $userId, isVerified: $isVerified');
      
      // First check if the document exists
      final docRef = _firestore.collection('users').doc(userId);
      final doc = await docRef.get();
      
      print('Document exists: ${doc.exists}');
      if (doc.exists) {
        print('Current document data: ${doc.data()}');
        print('Current isPhoneVerified value: ${doc.data()?['isPhoneVerified']}');
        
        // Document exists, update it
        await docRef.update({'isPhoneVerified': isVerified});
        print('Update operation completed');
        
        // Verify the update
        final updatedDoc = await docRef.get();
        print('Updated document data: ${updatedDoc.data()}');
        print('Updated isPhoneVerified value: ${updatedDoc.data()?['isPhoneVerified']}');
      } else {
        print('Document does not exist, creating new document');
        // Document doesn't exist, create it with basic info
        await docRef.set({
          'uid': userId,
          'isPhoneVerified': isVerified,
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'user',
        });
        print('Document created with isPhoneVerified: $isVerified');
      }
      print('=== END PHONE VERIFICATION UPDATE DEBUG ===');
    } catch (e) {
      print('Error updating phone verification status: $e');
      throw Exception('Failed to update phone verification status: $e');
    }
  }

  // Get current user's phone verification status
  Future<bool> getPhoneVerificationStatus(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      return doc.data()?['isPhoneVerified'] ?? false;
    } catch (e) {
      return false;
    }
  }
} 