import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/phone_verification_service.dart';
import '../../utils/constants.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'dart:async';

class PhoneVerificationScreen extends StatefulWidget {
  final String currentPhone;
  final String originalUserId;
  final String originalEmail;
  final VoidCallback? onVerificationComplete;

  const PhoneVerificationScreen({
    Key? key,
    required this.currentPhone,
    required this.originalUserId,
    required this.originalEmail,
    this.onVerificationComplete,
  }) : super(key: key);

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController(text: '60');
  final _codeController = TextEditingController();
  final _phoneVerificationService = PhoneVerificationService();
  
  bool _isLoading = false;
  bool _codeSent = false;
  String _verificationId = '';
  String _errorMessage = '';
  int _timeoutSeconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    // Set the phone number from the user's profile (read-only)
    if (widget.currentPhone.isNotEmpty) {
      // If current phone starts with 60, use it as is, otherwise prepend 60
      if (widget.currentPhone.startsWith('60')) {
        _phoneController.text = widget.currentPhone;
      } else {
        _phoneController.text = '60${widget.currentPhone}';
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _timeoutSeconds = 60;
    });
    
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeoutSeconds--;
        });
        if (_timeoutSeconds <= 0) {
          setState(() {
            _canResend = true;
          });
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendVerificationCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _phoneVerificationService.sendVerificationCode(
        phoneNumber: _phoneController.text,
        onCodeSent: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoading = false;
          });
          _startResendTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification code sent to your phone'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onError: (String error) {
          setState(() {
            _errorMessage = error;
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_codeController.text.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a 6-digit verification code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final success = await _phoneVerificationService.verifyCode(
        verificationId: _verificationId,
        smsCode: _codeController.text,
      );

      if (success) {
        // Update phone verification status in Firestore for the original user
        print('=== PHONE VERIFICATION SCREEN DEBUG ===');
        print('OTP verification successful');
        print('Original user ID: ${widget.originalUserId}');
        print('Original user email: ${widget.originalEmail}');
        
        // Get the current user (should still be the original email user)
        final currentUser = FirebaseAuth.instance.currentUser;
        print('Current user after OTP verification: ${currentUser?.uid}');
        print('Current user email: ${currentUser?.email}');
        
        // Use the original user ID to update the correct document
        print('Calling updatePhoneVerificationStatus for original user...');
        await _phoneVerificationService.updatePhoneVerificationStatus(
          widget.originalUserId,
          true,
        );
        print('updatePhoneVerificationStatus completed');
        
        // The user should still be signed in with their original email
        // The AuthProvider's real-time listener will automatically update the UI
        print('Phone verification completed for user: ${widget.originalUserId}');
        print('User remains signed in with email: ${currentUser?.email}');
        print('=== END PHONE VERIFICATION SCREEN DEBUG ===');

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        widget.onVerificationComplete?.call();
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = 'Invalid verification code';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Verification'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6BC1D1),
              Color(0xFF9CE09D),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Verification will be sent to your registered phone number:',
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 16),
                // Phone number display (read-only)
                TextFormField(
                  controller: _phoneController,
                  enabled: false, // Make it read-only
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: const Icon(Icons.phone),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF65B36A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF65B36A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF2C6D5E), width: 2),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF65B36A)),
                    ),
                    labelStyle: const TextStyle(color: Colors.black),
                    floatingLabelStyle: const TextStyle(color: Colors.black),
                  ),
                ),
                const SizedBox(height: 24),
                if (!_codeSent) ...[
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendVerificationCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Send Verification Code'),
                  ),
                ] else ...[
                  const Text(
                    'Enter the 6-digit code sent to your phone',
                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      hintText: 'Enter 6-digit code',
                      prefixIcon: const Icon(Icons.security),
                      counterText: '',
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF65B36A)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF65B36A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF2C6D5E), width: 2),
                      ),
                      labelStyle: const TextStyle(color: Colors.black),
                      floatingLabelStyle: const TextStyle(color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Verify Code'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Didn\'t receive?',
                        style: TextStyle(color: Colors.white.withOpacity(0.8)),
                      ),
                      TextButton(
                        onPressed: _canResend ? _sendVerificationCode : null,
                        child: Text(
                          _canResend ? 'Resend' : 'Resend($_timeoutSeconds)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                // Error message
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 