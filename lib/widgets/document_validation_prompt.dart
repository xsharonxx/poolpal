import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class DocumentValidationPrompt extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onNavigateToLicense;
  final bool showLicense;

  const DocumentValidationPrompt({
    super.key, 
    required this.user,
    this.onNavigateToProfile,
    this.onNavigateToLicense,
    this.showLicense = false,
  });

  @override
  State<DocumentValidationPrompt> createState() => _DocumentValidationPromptState();
}

class _DocumentValidationPromptState extends State<DocumentValidationPrompt> {
  Stream<DocumentSnapshot?>? _icDocumentStream;
  Stream<DocumentSnapshot?>? _licenseDocumentStream;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
  }

  void _initializeStreams() {
    _icDocumentStream = FirebaseFirestore.instance
        .collection('ic')
        .where('uid', isEqualTo: widget.user.uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null);

    if (widget.showLicense) {
      _licenseDocumentStream = FirebaseFirestore.instance
          .collection('license')
          .where('uid', isEqualTo: widget.user.uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots()
          .map((querySnapshot) => querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showLicense) {
      // Only show IC document (for Find Ride)
      return StreamBuilder<DocumentSnapshot?>(
        stream: _icDocumentStream,
        builder: (context, snapshot) {
          String? icStatus;
          
          if (snapshot.hasData && snapshot.data != null) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data != null) {
              icStatus = data['status'] as String?;
            }
          }

          // If IC is verified, don't show anything
          if (icStatus == 'verified') {
            return const SizedBox.shrink();
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description,
                      color: Colors.red.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Document Required',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDocumentItem(
                  context,
                  'IC Document',
                  Icons.credit_card,
                  icStatus,
                  widget.onNavigateToProfile,
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Show both IC and License documents (for Offer Ride)
      return StreamBuilder<DocumentSnapshot?>(
        stream: _icDocumentStream,
        builder: (context, icSnapshot) {
          String? icStatus;
          
          if (icSnapshot.hasData && icSnapshot.data != null) {
            final data = icSnapshot.data!.data() as Map<String, dynamic>?;
            if (data != null) {
              icStatus = data['status'] as String?;
            }
          }

          return StreamBuilder<DocumentSnapshot?>(
            stream: _licenseDocumentStream,
            builder: (context, licenseSnapshot) {
              String? licenseStatus;
              
              if (licenseSnapshot.hasData && licenseSnapshot.data != null) {
                final data = licenseSnapshot.data!.data() as Map<String, dynamic>?;
                if (data != null) {
                  licenseStatus = data['status'] as String?;
                }
              }

              // If both are verified, don't show anything
              if (icStatus == 'verified' && licenseStatus == 'verified') {
                return const SizedBox.shrink();
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description,
                          color: Colors.red.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Document Required',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (icStatus != 'verified') ...[
                      _buildDocumentItem(
                        context,
                        'IC Document',
                        Icons.credit_card,
                        icStatus,
                        widget.onNavigateToProfile,
                      ),
                      if (licenseStatus != 'verified') const SizedBox(height: 8),
                    ],
                    if (licenseStatus != 'verified') ...[
                      _buildDocumentItem(
                        context,
                        'License Document',
                        Icons.drive_eta,
                        licenseStatus,
                        widget.onNavigateToLicense,
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  Widget _buildDocumentItem(
    BuildContext context,
    String title,
    IconData icon,
    String? status,
    VoidCallback? onTap,
  ) {
    Color itemColor;
    String buttonText;
    bool isVerified = status == 'verified';

    if (isVerified) {
      itemColor = Colors.green;
      buttonText = 'Verified';
    } else if (status == 'pending') {
      itemColor = Colors.orange;
      buttonText = 'Pending';
    } else if (status == 'reject') {
      itemColor = Colors.red;
      buttonText = 'Rejected';
    } else {
      itemColor = Colors.blue;
      buttonText = 'Verify';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: isVerified ? null : onTap,
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
                buttonText,
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
} 