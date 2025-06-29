import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as local_auth;
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/auth/phone_verification_screen.dart';

class VerificationPrompt extends StatefulWidget {
  final UserModel user;

  const VerificationPrompt({super.key, required this.user});

  @override
  State<VerificationPrompt> createState() => _VerificationPromptState();
}

class _VerificationPromptState extends State<VerificationPrompt> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshEmailVerification();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshEmailVerification();
    }
  }

  Future<void> _refreshEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<local_auth.AuthProvider>();
    final isEmailVerified = authProvider.isEmailVerified();
    final isPhoneVerified = widget.user.isPhoneVerified ?? false;

    // If both are verified, don't show anything
    if (isEmailVerified && isPhoneVerified) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Verification Required',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isEmailVerified) ...[
            _buildVerificationItem(
              context,
              'Email Verification',
              Icons.email,
              isEmailVerified,
              () => _handleEmailVerification(context, authProvider),
            ),
            if (!isPhoneVerified) const SizedBox(height: 8),
          ],
          if (!isPhoneVerified) ...[
            _buildVerificationItem(
              context,
              'Phone Verification',
              Icons.phone,
              isPhoneVerified,
              () => _handlePhoneVerification(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationItem(
    BuildContext context,
    String title,
    IconData icon,
    bool isVerified,
    VoidCallback onTap,
  ) {
    // Determine colors based on verification type
    Color itemColor;
    if (title == 'Email Verification') {
      itemColor = isVerified ? Colors.green : Colors.blue;
    } else {
      itemColor = isVerified ? Colors.green : Colors.green;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: itemColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: itemColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: itemColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: itemColor,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: itemColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                isVerified ? 'Verified' : 'Verify',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleEmailVerification(BuildContext context, local_auth.AuthProvider authProvider) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.sendEmailVerification();
        if (!context.mounted) return;
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Verify your email',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: const Text('A verification link has been sent to your inbox. Please check your email and click the verification link.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handlePhoneVerification(BuildContext context) {
    // Navigate to phone verification screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhoneVerificationScreen(
          currentPhone: widget.user.phone ?? '',
          originalUserId: widget.user.uid,
          originalEmail: widget.user.email,
        ),
      ),
    );
  }
} 