import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import '../../models/user_model.dart';
import 'package:rxdart/rxdart.dart';

class UserDetailScreen extends StatefulWidget {
  final String uid;
  final String userName;

  const UserDetailScreen({
    super.key,
    required this.uid,
    required this.userName,
  });

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final TextEditingController _rejectReasonController = TextEditingController();
  bool _isUpdating = false;
  bool _showRejectError = false;

  @override
  void dispose() {
    _rejectReasonController.dispose();
    super.dispose();
  }

  Future<void> _updateDocumentStatus(String collection, String docId, String status, {String? reason}) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (reason != null && reason.isNotEmpty) {
        updateData['rejectReason'] = reason;
      }

      // Update the document status
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .update(updateData);

      // If document is verified, update user's verification status
      if (status == 'verified') {
        final userUpdateData = <String, dynamic>{};
        
        if (collection == 'ic') {
          userUpdateData['isICVerified'] = true;
        } else if (collection == 'license') {
          userUpdateData['isLicenseVerified'] = true;
        }
        
        if (userUpdateData.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .update(userUpdateData);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$collection status updated to $status'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _showRejectDialog(String collection, String docId) async {
    // Clear error state when dialog opens
    setState(() {
      _showRejectError = false;
    });
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Reject ${collection.toUpperCase()}',
                      style: const TextStyle(
                        color: Color(0xFF2C6D5E),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Please provide a reason for rejection:',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _rejectReasonController,
                            onChanged: (value) {
                              if (_showRejectError && value.trim().isNotEmpty) {
                                setDialogState(() {
                                  _showRejectError = false;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Enter rejection reason',
                              errorText: _showRejectError ? 'Required**' : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF65B36A)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _showRejectError ? Colors.red : const Color(0xFF65B36A),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _showRejectError ? Colors.red : const Color(0xFF2C6D5E),
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.red, width: 2),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.red, width: 2),
                              ),
                              fillColor: Colors.grey[50],
                              filled: true,
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _rejectReasonController.clear();
                            setState(() {
                              _showRejectError = false;
                            });
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[600],
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            final reason = _rejectReasonController.text.trim();
                            if (reason.isEmpty) {
                              setDialogState(() {
                                _showRejectError = true;
                              });
                              return;
                            }
                            
                            Navigator.of(context).pop();
                            await _updateDocumentStatus(collection, docId, 'reject', reason: reason);
                            _rejectReasonController.clear();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Reject',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Information Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C6D5E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildNameRowWithImage(),
                    _buildInfoRow('UID', widget.uid),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final userData = snapshot.data!.data() as Map<String, dynamic>;
                          
                          // Helper function to parse date from string or timestamp
                          DateTime? parseDate(dynamic dateValue) {
                            if (dateValue == null) return null;
                            if (dateValue is Timestamp) {
                              return dateValue.toDate();
                            } else if (dateValue is String) {
                              try {
                                return DateTime.parse(dateValue);
                              } catch (e) {
                                return null;
                              }
                            }
                            return null;
                          }
                          
                          final dateOfBirth = parseDate(userData['dateOfBirth']);
                          final createdAt = parseDate(userData['createdAt']);
                          
                          return Column(
                            children: [
                              _buildInfoRow('Email', userData['email'] ?? 'N/A'),
                              _buildInfoRow('Phone', userData['phone'] ?? 'N/A'),
                              if (dateOfBirth != null)
                                _buildInfoRow('Date of Birth', DateFormat.yMMMd().format(dateOfBirth)),
                              _buildInfoRow('Gender', userData['gender'] ?? 'N/A'),
                              _buildInfoRow('Race', userData['race'] ?? 'N/A'),
                              if (createdAt != null)
                                _buildInfoRow('Joined', DateFormat.yMMMd().format(createdAt)),
                            ],
                          );
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Document Sections - Show based on verification status priority
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getDocumentSections(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final documentSections = snapshot.data ?? [];
                  
                  if (documentSections.isEmpty) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: const Text(
                        'No documents submitted',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }
                  
                  return Column(
                    children: documentSections.asMap().entries.map((entry) {
                      final index = entry.key;
                      final section = entry.value;
                      
                      return Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${section['type']} Document',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C6D5E),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildDocumentSection(
                                  section['type'],
                                  section['docId'],
                                  section['status'],
                                  section['photoUrl'],
                                  section['createdAt'],
                                  section['rejectReason'],
                                ),
                              ],
                            ),
                          ),
                          if (index < documentSections.length - 1) const SizedBox(height: 20),
                        ],
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C6D5E),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameRowWithImage() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String? photoUrl;
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          photoUrl = userData['photoUrl'];
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              if (photoUrl != null && photoUrl.isNotEmpty)
                CircleAvatar(
                  radius: 32,
                  backgroundImage: NetworkImage(photoUrl),
                  onBackgroundImageError: (exception, stackTrace) {
                    // Handle image loading error
                  },
                )
              else
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFF65B36A),
                  child: Text(
                    widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentSection(String type, String docId, String? status, String? photoUrl, DateTime? createdAt, String? rejectReason) {
    final statusColor = _getStatusColor(status);
    final isPending = status == 'pending';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Document ID: $docId',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2C6D5E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Status', status?.toUpperCase() ?? 'UNKNOWN'),
          if (createdAt != null)
            _buildInfoRow('Submitted', DateFormat.yMMMd().add_jm().format(createdAt)),
          if (rejectReason != null)
            _buildInfoRow('Reason', rejectReason),
          
          if (photoUrl != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
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
                              photoUrl,
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
              child: AspectRatio(
                aspectRatio: 1.6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    photoUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
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
          ],
          
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : () async {
                      await _updateDocumentStatus(type.toLowerCase(), docId, 'verified');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Approve',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : () async {
                      await _showRejectDialog(type.toLowerCase(), docId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Reject',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'verified':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Stream<List<Map<String, dynamic>>> _getDocumentSections() {
    return Rx.combineLatest2(
      FirebaseFirestore.instance
          .collection('ic')
          .where('uid', isEqualTo: widget.uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      FirebaseFirestore.instance
          .collection('license')
          .where('uid', isEqualTo: widget.uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      (QuerySnapshot icSnapshot, QuerySnapshot licenseSnapshot) {
        List<Map<String, dynamic>> sections = [];
        
        // Helper function to parse date from string or timestamp
        DateTime? parseDate(dynamic dateValue) {
          if (dateValue == null) return null;
          if (dateValue is Timestamp) {
            return dateValue.toDate();
          } else if (dateValue is String) {
            try {
              return DateTime.parse(dateValue);
            } catch (e) {
              return null;
            }
          }
          return null;
        }
        
        // Process IC document
        if (icSnapshot.docs.isNotEmpty) {
          final icDoc = icSnapshot.docs.first;
          final icData = icDoc.data() as Map<String, dynamic>;
          sections.add({
            'type': 'IC',
            'docId': icDoc.id,
            'status': icData['status'] as String?,
            'photoUrl': icData['photourl'] as String?,
            'createdAt': parseDate(icData['createdAt']),
            'rejectReason': icData['rejectReason'] as String?,
            'priority': icData['status'] == 'verified' ? 1 : 2,
          });
        }
        
        // Process License document
        if (licenseSnapshot.docs.isNotEmpty) {
          final licenseDoc = licenseSnapshot.docs.first;
          final licenseData = licenseDoc.data() as Map<String, dynamic>;
          sections.add({
            'type': 'License',
            'docId': licenseDoc.id,
            'status': licenseData['status'] as String?,
            'photoUrl': licenseData['photourl'] as String?,
            'createdAt': parseDate(licenseData['createdAt']),
            'rejectReason': licenseData['rejectReason'] as String?,
            'priority': licenseData['status'] == 'verified' ? 1 : 2,
          });
        }
        
        // Sort by priority (verified first) and then by type
        sections.sort((a, b) {
          if (a['priority'] != b['priority']) {
            return a['priority'].compareTo(b['priority']);
          }
          return a['type'].compareTo(b['type']);
        });
        
        return sections;
      },
    );
  }
} 