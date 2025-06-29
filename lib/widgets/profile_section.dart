import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_provider.dart' as local_auth;
import '../screens/auth/phone_verification_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'dart:async';

class ProfileSection extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onEdit;
  final bool isPhoneVerified;
  final String? licenseStatus;
  final String? icStatus;
  final VoidCallback? onResetPassword;
  final bool scrollToIC;
  final bool scrollToLicense;

  const ProfileSection({
    Key? key,
    required this.user,
    this.onEdit,
    this.isPhoneVerified = false,
    this.licenseStatus,
    this.icStatus,
    this.onResetPassword,
    this.scrollToIC = false,
    this.scrollToLicense = false,
  }) : super(key: key);

  @override
  State<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<ProfileSection> with WidgetsBindingObserver {
  bool _emailVerified = false;
  Uint8List? _icImagePreview;
  Uint8List? _licenseImagePreview;
  bool _isUploadingIc = false;
  bool _isUploadingLicense = false;
  String? _icImageUrl;
  String? _icStatus;
  String? _licenseImageUrl;
  String? _licenseStatus;
  StreamSubscription<DocumentSnapshot>? _icDocSubscription;
  StreamSubscription<DocumentSnapshot>? _licenseDocSubscription;
  String? _icDocId;
  String? _licenseDocId;
  bool _listenersInitialized = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _icSectionKey = GlobalKey();
  final GlobalKey _licenseSectionKey = GlobalKey();
  bool _icSectionRendered = false;
  bool _licenseSectionRendered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reloadEmailVerification();
    
    // Scroll to IC or License section if requested
    if (widget.scrollToIC || widget.scrollToLicense) {
      // Use a shorter delay and then check if widgets are ready
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _attemptScrollToSection();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _icDocSubscription?.cancel();
    _licenseDocSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadEmailVerification();
    }
  }

  Future<void> _reloadEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      setState(() {
        _emailVerified = user.emailVerified;
      });
    }
  }

  Stream<DocumentSnapshot?> _getDocumentStream(String collection, String uid) {
    return FirebaseFirestore.instance
        .collection(collection)
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: widget.user.photoUrl != null && widget.user.photoUrl!.isNotEmpty
                          ? CircleAvatar(
                              radius: 48,
                              backgroundColor: AppColors.primary.withOpacity(0.2),
                              backgroundImage: NetworkImage(widget.user.photoUrl!),
                            )
                          : CircleAvatar(
                              radius: 48,
                              backgroundColor: AppColors.primary.withOpacity(0.2),
                              child: Icon(Icons.person, size: 48, color: AppColors.primary),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        widget.user.fullName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: widget.onResetPassword,
                        icon: const Icon(Icons.lock_reset, color: AppColors.primary),
                        label: const Text(
                          'Reset Password',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _infoRowWithVerifyIcon(
                              'Email:',
                      widget.user.email,
                      _emailVerified,
                    ),
                    if (widget.user.phone != null && widget.user.phone!.isNotEmpty)
                      _infoRowWithVerifyIcon(
                        'Phone:',
                        widget.user.phone!,
                        widget.isPhoneVerified,
                      ),
                    const SizedBox(height: 12),
                    if (widget.user.dateOfBirth != null)
                      _infoRow(
                        'Date of Birth:',
                        DateFormat.yMMMd().format(widget.user.dateOfBirth!),
                      ),
                    if (widget.user.gender != null && widget.user.gender!.isNotEmpty)
                      _infoRow('Gender:', widget.user.gender!),
                    if (widget.user.race != null && widget.user.race!.isNotEmpty)
                      _infoRow('Race:', widget.user.race!),
                    _infoRow('Joined:', DateFormat.yMMMd().format(widget.user.createdAt)),
                    const SizedBox(height: 16),
                    if (widget.user.role != 'admin') ...[
                      StreamBuilder<DocumentSnapshot?>(
                        key: _icSectionKey,
                        stream: _getDocumentStream('ic', widget.user.uid),
                        builder: (context, snapshot) {
                          // Mark IC section as rendered when we have data
                          if (!_icSectionRendered && snapshot.connectionState == ConnectionState.active) {
                            _icSectionRendered = true;
                            if (widget.scrollToIC) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _scrollToICSection();
                              });
                            }
                          }
                          
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'IC',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                  ),
                                  const Text(
                                    'Loading...',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          String? icStatus;
                          String? icImageUrl;
                          
                          if (snapshot.hasData && snapshot.data != null) {
                            final data = snapshot.data!.data() as Map<String, dynamic>?;
                            if (data != null) {
                              icStatus = data['status'] as String?;
                              icImageUrl = data['photourl'] as String?;
                            }
                          }
                          
                          return _sectionStatus(
                            'IC',
                            _icImagePreview != null ? 'pending' : (icStatus ?? widget.icStatus),
                            sectionKey: 'ic',
                            imagePreview: _icImagePreview,
                            imageUrl: icImageUrl,
                            onImageSubmit: _handleImageSubmit,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<DocumentSnapshot?>(
                        key: _licenseSectionKey,
                        stream: _getDocumentStream('license', widget.user.uid),
                        builder: (context, snapshot) {
                          // Mark License section as rendered when we have data
                          if (!_licenseSectionRendered && snapshot.connectionState == ConnectionState.active) {
                            _licenseSectionRendered = true;
                            if (widget.scrollToLicense) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _scrollToLicenseSection();
                              });
                            }
                          }
                          
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'License',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                  ),
                                  const Text(
                                    'Loading...',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          String? licenseStatus;
                          String? licenseImageUrl;
                          
                          if (snapshot.hasData && snapshot.data != null) {
                            final data = snapshot.data!.data() as Map<String, dynamic>?;
                            if (data != null) {
                              licenseStatus = data['status'] as String?;
                              licenseImageUrl = data['photourl'] as String?;
                            }
                          }
                          
                          return _sectionStatus(
                            'License',
                            _licenseImagePreview != null ? 'pending' : (licenseStatus ?? widget.licenseStatus),
                            sectionKey: 'license',
                            imagePreview: _licenseImagePreview,
                            imageUrl: licenseImageUrl,
                            onImageSubmit: _handleImageSubmit,
                          );
                        },
                      ),
                    ],
                  ],
                ),
                if (widget.onEdit != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.primary),
                      onPressed: widget.onEdit,
                      tooltip: 'Edit Profile',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
                label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRowWithVerifyIcon(String label, String value, bool isVerified) {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                    label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      if (label == 'Email:') {
                        final user = FirebaseAuth.instance.currentUser;
                        if (!isVerified && user != null) {
                          await user.sendEmailVerification();
                          if (mounted) {
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
                                content: const Text('A verification link has been sent to your inbox. Please check.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          }
                        } else if (isVerified) {
                          showDialog(
                            context: context,
                            builder: (context) => const AlertDialog(
                              title: Text('Already verified'),
                              content: Text('Your email is already verified.'),
                            ),
                          );
                        }
                      } else if (label == 'Phone:') {
                        if (!isVerified) {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PhoneVerificationScreen(
                                currentPhone: value,
                            originalUserId: widget.user.uid,
                            originalEmail: widget.user.email,
                                onVerificationComplete: () {
                              // The AuthProvider real-time listener will handle the UI update
                                },
                              ),
                            ),
                          );
                        } else {
                          showDialog(
                            context: context,
                            builder: (context) => const AlertDialog(
                              title: Text('Already verified'),
                              content: Text('Your phone number is already verified.'),
                            ),
                          );
                        }
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Flexible(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.verified,
                          color: isVerified ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                      ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionStatus(String title, String? status, {
    required String sectionKey, // 'ic' or 'license'
    Uint8List? imagePreview,
    String? imageUrl,
    required void Function(Uint8List, String) onImageSubmit,
  }) {
    Color color;
    IconData icon;
    String displayText = status ?? 'Verify Now';
    bool isActionable = false;
    bool isLoading = false;
    
    // Check if currently uploading
    if (sectionKey == 'ic' && _isUploadingIc) {
      isLoading = true;
      color = Colors.blue;
      icon = Icons.upload;
      displayText = 'Uploading...';
      isActionable = false;
    } else if (sectionKey == 'license' && _isUploadingLicense) {
      isLoading = true;
      color = Colors.blue;
      icon = Icons.upload;
      displayText = 'Uploading...';
      isActionable = false;
    } else if (status == null) {
      color = Colors.blue;
      icon = Icons.info_outline;
      displayText = 'Verify Now';
      isActionable = true;
    } else {
      switch (status.toLowerCase()) {
        case 'verified':
          color = Colors.green;
          icon = Icons.check_circle;
          break;
        case 'reject':
          color = Colors.red;
          icon = Icons.cancel;
          isActionable = true;
          break;
        case 'pending':
          color = Colors.orange;
          icon = Icons.hourglass_top;
          break;
        default:
          color = Colors.blue;
          icon = Icons.info_outline;
          displayText = 'Verify Now';
          isActionable = true;
      }
    }
    
    Widget content = Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
          Text(
                displayText.isNotEmpty
                    ? displayText[0].toUpperCase() + displayText.substring(1)
                    : displayText,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          if (status != null && status.toLowerCase() == 'reject')
            StreamBuilder<DocumentSnapshot?>(
              stream: _getDocumentStream(sectionKey, widget.user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  final reason = data != null && data['rejectReason'] != null ? data['rejectReason'] as String : null;
                  if (reason != null && reason.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        'Reason: $reason',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          if (imagePreview != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AspectRatio(
                aspectRatio: 1.6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Image.memory(
                        imagePreview,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      if (isLoading)
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (imageUrl != null && imagePreview == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AspectRatio(
                aspectRatio: 1.6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.all(8),
                          child: Stack(
                            children: [
                              // Full screen image
                              Center(
                                child: InteractiveViewer(
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        color: Colors.black,
                                        child: const Center(
                                          child: Icon(Icons.error, size: 64, color: Colors.white),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              // Close button
                              Positioned(
                                top: 40,
                                right: 20,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.error, size: 48, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ),
        ],
      ),
    );
    
    if (isActionable && !isLoading) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picker = ImagePicker();
          final picked = await picker.pickImage(source: ImageSource.camera);
          if (picked != null) {
            final bytes = await picked.readAsBytes();
            showGeneralDialog(
              context: context,
              barrierDismissible: true,
              barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
              pageBuilder: (context, anim1, anim2) {
                final CropController _docCropController = CropController();
                bool isSubmitting = false;
                
                return StatefulBuilder(
                  builder: (context, setDialogState) {
                    final double dialogWidth = MediaQuery.of(context).size.width - 16;
                    return SafeArea(
                      child: Center(
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: dialogWidth,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Crop Image',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: dialogWidth,
                                  height: 300,
                                  child: Crop(
                                    image: bytes,
                                    controller: _docCropController,
                                    onCropped: (croppedData) async {
                                      setDialogState(() {
                                        isSubmitting = true;
                                      });
                                      Navigator.of(context).pop();
                                      onImageSubmit(croppedData, sectionKey);
                                    },
                                    aspectRatio: 1.6,
                                    initialSize: 0.8,
                                    baseColor: Colors.black,
                                    maskColor: Colors.black.withOpacity(0.4),
                                    withCircleUi: false,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: isSubmitting ? null : () {
                                          setDialogState(() {
                                            isSubmitting = true;
                                          });
                                          _docCropController.crop();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: isSubmitting
                                            ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : const Text('Submit'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }
        },
        child: content,
      );
    } else {
      return content;
    }
  }

  Future<void> _handleImageSubmit(Uint8List croppedData, String sectionKey) async {
    setState(() {
      if (sectionKey == 'ic') {
        _icImagePreview = croppedData;
        _isUploadingIc = true;
      } else if (sectionKey == 'license') {
        _licenseImagePreview = croppedData;
        _isUploadingLicense = true;
      }
    });

    try {
      final docRef = FirebaseFirestore.instance.collection(sectionKey).doc();
      final storageRef = FirebaseStorage.instance.ref().child('$sectionKey/${docRef.id}/${widget.user.uid}.jpg');
      
      // Show upload progress
      final uploadTask = storageRef.putData(croppedData, SettableMetadata(contentType: 'image/jpeg'));
      
      // Wait for upload to complete
      await uploadTask;
      
      final downloadUrl = await storageRef.getDownloadURL();
      await docRef.set({
        'uid': widget.user.uid,
        'photourl': downloadUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        if (sectionKey == 'ic') {
          _icImageUrl = downloadUrl;
          _icImagePreview = null;
          _isUploadingIc = false;
        } else if (sectionKey == 'license') {
          _licenseImageUrl = downloadUrl;
          _licenseImagePreview = null;
          _isUploadingLicense = false;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${sectionKey[0].toUpperCase()}${sectionKey.substring(1)} photo submitted and pending review!')),
      );
    } catch (e) {
      setState(() {
        if (sectionKey == 'ic') {
          _isUploadingIc = false;
        } else if (sectionKey == 'license') {
          _isUploadingLicense = false;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload ${sectionKey[0].toUpperCase()}${sectionKey.substring(1)} photo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _attemptScrollToSection() {
    if (widget.scrollToIC && _icSectionRendered) {
      _scrollToICSection();
    } else if (widget.scrollToLicense && _licenseSectionRendered) {
      _scrollToLicenseSection();
    } else {
      // Fallback: if sections aren't rendered yet, try again after a short delay
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          if (widget.scrollToIC) {
            _scrollToICSection();
          } else if (widget.scrollToLicense) {
            _scrollToLicenseSection();
          }
        }
      });
    }
  }

  void _scrollToICSection() {
    print('Attempting to scroll to IC section');
    if (_icSectionKey.currentContext != null) {
      print('IC section key context found, scrolling...');
      try {
        Scrollable.ensureVisible(
          _icSectionKey.currentContext!,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
        print('IC section scroll completed');
      } catch (e) {
        print('Error scrolling to IC section: $e');
      }
    } else {
      print('IC section key context is null');
    }
  }

  void _scrollToLicenseSection() {
    print('Attempting to scroll to License section');
    if (_licenseSectionKey.currentContext != null) {
      print('License section key context found, scrolling...');
      try {
        Scrollable.ensureVisible(
          _licenseSectionKey.currentContext!,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
        print('License section scroll completed');
      } catch (e) {
        print('Error scrolling to License section: $e');
      }
    } else {
      print('License section key context is null');
    }
  }
} 
