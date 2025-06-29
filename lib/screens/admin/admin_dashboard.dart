import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart' as local_auth;
import '../../utils/constants.dart';
import '../../widgets/profile_section.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import 'user_detail_screen.dart';
import 'package:rxdart/rxdart.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  static List<Widget> get _pages => [
    const _UserManagementPage(),
    Builder(
      builder: (context) {
        final user = context.watch<local_auth.AuthProvider>().user;
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ProfileSection(user: user);
      },
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<local_auth.AuthProvider>().user;
    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    Text(
                      'PoolPal',
                      style: GoogleFonts.pacifico(
                        fontSize: 28,
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Colors.black12,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '- Admin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (!mounted) return;
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _pages[_selectedIndex],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildCustomBottomNavigation(),
    );
  }

  Widget _buildCustomBottomNavigation() {
    final double navBarHeight = 72;
    final double iconSize = 24;
    final Color selectedColor = AppColors.primary;
    final Color unselectedColor = Colors.grey;
    return SizedBox(
      height: navBarHeight + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: navBarHeight,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.people, 'User Management', iconSize, selectedColor, unselectedColor),
                  _buildNavItem(1, Icons.person, 'Profile', iconSize, selectedColor, unselectedColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, double iconSize, Color selectedColor, Color unselectedColor) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: SizedBox(
        width: 120,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: iconSize,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? selectedColor : unselectedColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserManagementPage extends StatefulWidget {
  const _UserManagementPage();

  @override
  State<_UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<_UserManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'ic'; // 'ic' or 'license'
  bool _sortAscending = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Simulate refresh delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _isLoading = false;
    });
  }

  Stream<List<UserSubmissionData>> _getUserSubmissions() {
    return Rx.combineLatest2(
      FirebaseFirestore.instance
          .collection('ic')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      FirebaseFirestore.instance
          .collection('license')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      (QuerySnapshot icSnapshot, QuerySnapshot licenseSnapshot) async {
        // Get all unique user IDs with pending documents
        Set<String> pendingUserIds = {};
        
        // Add users with pending IC documents
        for (var doc in icSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final uid = data['uid'] as String?;
          if (uid != null) pendingUserIds.add(uid);
        }
        
        // Add users with pending license documents
        for (var doc in licenseSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final uid = data['uid'] as String?;
          if (uid != null) pendingUserIds.add(uid);
        }
        
        // Fetch user data for all pending users
        List<UserSubmissionData> submissions = [];
        
        for (String uid in pendingUserIds) {
          // Get user data
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          
          if (!userDoc.exists) continue;
          
          final userData = userDoc.data()!;
          
          // Get the latest pending IC document for this user
          final icQuery = await FirebaseFirestore.instance
              .collection('ic')
              .where('uid', isEqualTo: uid)
              .where('status', isEqualTo: 'pending')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();
          
          // Get the latest pending license document for this user
          final licenseQuery = await FirebaseFirestore.instance
              .collection('license')
              .where('uid', isEqualTo: uid)
              .where('status', isEqualTo: 'pending')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();
          
          final icDoc = icQuery.docs.isNotEmpty ? icQuery.docs.first : null;
          final licenseDoc = licenseQuery.docs.isNotEmpty ? licenseQuery.docs.first : null;
          
          submissions.add(UserSubmissionData(
            uid: uid,
            userName: userData['fullName'] ?? 'Unknown',
            icDocId: icDoc?.id,
            icCreatedAt: icDoc?.data()['createdAt'] as Timestamp?,
            icStatus: icDoc?.data()['status'] as String?,
            licenseDocId: licenseDoc?.id,
            licenseCreatedAt: licenseDoc?.data()['createdAt'] as Timestamp?,
            licenseStatus: licenseDoc?.data()['status'] as String?,
          ));
        }
        
        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          submissions = submissions.where((submission) {
            final query = _searchQuery.toLowerCase();
            return submission.uid.toLowerCase().contains(query) ||
                   submission.userName.toLowerCase().contains(query) ||
                   (submission.icDocId?.toLowerCase().contains(query) ?? false) ||
                   (submission.licenseDocId?.toLowerCase().contains(query) ?? false);
          }).toList();
        }
        
        // Apply sorting
        submissions.sort((a, b) {
          if (_sortBy == 'ic') {
            // Check if both users have IC documents
            final aHasIc = a.icCreatedAt != null;
            final bHasIc = b.icCreatedAt != null;
            
            // If one has IC and the other doesn't, put the one without IC at the end
            if (aHasIc && !bHasIc) return -1;
            if (!aHasIc && bHasIc) return 1;
            
            // If both have IC, sort by creation time
            if (aHasIc && bHasIc) {
              final comparison = a.icCreatedAt!.compareTo(b.icCreatedAt!);
              return _sortAscending ? comparison : -comparison;
            }
            
            // If neither has IC, sort by license creation time as fallback
            final aLicenseTime = a.licenseCreatedAt ?? Timestamp.fromDate(DateTime(1900));
            final bLicenseTime = b.licenseCreatedAt ?? Timestamp.fromDate(DateTime(1900));
            final comparison = aLicenseTime.compareTo(bLicenseTime);
            return _sortAscending ? comparison : -comparison;
          } else {
            // Check if both users have license documents
            final aHasLicense = a.licenseCreatedAt != null;
            final bHasLicense = b.licenseCreatedAt != null;
            
            // If one has license and the other doesn't, put the one without license at the end
            if (aHasLicense && !bHasLicense) return -1;
            if (!aHasLicense && bHasLicense) return 1;
            
            // If both have license, sort by creation time
            if (aHasLicense && bHasLicense) {
              final comparison = a.licenseCreatedAt!.compareTo(b.licenseCreatedAt!);
              return _sortAscending ? comparison : -comparison;
            }
            
            // If neither has license, sort by IC creation time as fallback
            final aIcTime = a.icCreatedAt ?? Timestamp.fromDate(DateTime(1900));
            final bIcTime = b.icCreatedAt ?? Timestamp.fromDate(DateTime(1900));
            final comparison = aIcTime.compareTo(bIcTime);
            return _sortAscending ? comparison : -comparison;
          }
        });
        
        return submissions;
      },
    ).switchMap((future) => Stream.fromFuture(future));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and Filter Section
        Column(
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 12),
            // Filter Row
            Row(
              children: [
                const Text(
                  'Sort by: ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _sortBy,
                      underline: Container(),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'ic', child: Text('IC')),
                        DropdownMenuItem(value: 'license', child: Text('License')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sortBy = value!;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                    onPressed: () {
                      setState(() {
                        _sortAscending = !_sortAscending;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // User List
        Expanded(
          child: StreamBuilder<List<UserSubmissionData>>(
            stream: _getUserSubmissions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }
              
              final submissions = snapshot.data ?? [];
              
              if (submissions.isEmpty) {
                return const Center(
                  child: Text('No result found'),
                );
              }
              
              return RefreshIndicator(
                onRefresh: _refreshData,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: submissions.length,
                  itemBuilder: (context, index) {
                    final submission = submissions[index];
                    return _buildUserCard(submission);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(UserSubmissionData submission) {
    final hasIC = submission.icDocId != null;
    final hasLicense = submission.licenseDocId != null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailScreen(
                uid: submission.uid,
                userName: submission.userName,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with UID and Username
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UID: ${submission.uid}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'User: ${submission.userName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                ],
              ),
              const SizedBox(height: 12),
              // Only show IC Information if submitted
              if (hasIC) ...[
                _buildDocumentInfo(
                  'IC',
                  submission.icDocId,
                  submission.icCreatedAt,
                  submission.icStatus,
                ),
                if (hasLicense) const SizedBox(height: 8),
              ],
              // Only show License Information if submitted
              if (hasLicense)
                _buildDocumentInfo(
                  'License',
                  submission.licenseDocId,
                  submission.licenseCreatedAt,
                  submission.licenseStatus,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentInfo(String type, String? docId, Timestamp? createdAt, String? status) {
    final hasDocument = docId != null;
    final statusColor = _getStatusColor(status);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: hasDocument ? statusColor : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$type: ${hasDocument ? docId : 'Not submitted'}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: hasDocument ? Colors.black : Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (hasDocument && createdAt != null)
                Text(
                  'Created: ${_formatTimestamp(createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              if (hasDocument && status != null)
                Text(
                  'Status: ${status.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
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

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class UserSubmissionData {
  final String uid;
  final String userName;
  final String? icDocId;
  final Timestamp? icCreatedAt;
  final String? icStatus;
  final String? licenseDocId;
  final Timestamp? licenseCreatedAt;
  final String? licenseStatus;

  UserSubmissionData({
    required this.uid,
    required this.userName,
    this.icDocId,
    this.icCreatedAt,
    this.icStatus,
    this.licenseDocId,
    this.licenseCreatedAt,
    this.licenseStatus,
  });
} 