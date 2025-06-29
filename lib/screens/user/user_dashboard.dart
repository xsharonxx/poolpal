import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/profile_section.dart';
import '../../widgets/verification_prompt.dart';
import '../../widgets/document_validation_prompt.dart';
import 'package:intl/intl.dart';
import 'edit_profile_screen.dart';
import '../../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_ride_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;
  bool _scrollToIC = false;
  bool _scrollToLicense = false;

  List<Widget> get _pages {
    if (_scrollToIC) {
      return _pagesWithICScroll;
    } else if (_scrollToLicense) {
      return _pagesWithLicenseScroll;
    } else {
      return _pagesNormal;
    }
  }

  static List<Widget> get _pagesNormal => [
    const _HomePage(),
    const _FindRidePage(),
    const _OfferRidePage(),
    const _MyTripPage(),
    const _ProfilePage(scrollToIC: false, scrollToLicense: false),
  ];

  static List<Widget> get _pagesWithICScroll => [
    const _HomePage(),
    const _FindRidePage(),
    const _OfferRidePage(),
    const _MyTripPage(),
    const _ProfilePage(scrollToIC: true, scrollToLicense: false),
  ];

  static List<Widget> get _pagesWithLicenseScroll => [
    const _HomePage(),
    const _FindRidePage(),
    const _OfferRidePage(),
    const _MyTripPage(),
    const _ProfilePage(scrollToIC: false, scrollToLicense: true),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Reset scroll flags after navigating to profile
      if (index == 4) {
        _scrollToIC = false;
        _scrollToLicense = false;
      }
    });
  }

  void _navigateToProfileWithICScroll() {
    setState(() {
      _selectedIndex = 4;
      _scrollToIC = true;
      _scrollToLicense = false;
    });
  }

  void _navigateToProfileWithLicenseScroll() {
    setState(() {
      _selectedIndex = 4;
      _scrollToIC = false;
      _scrollToLicense = true;
    });
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
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
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () async {
                        await context.read<AuthProvider>().signOut();
                        if (!context.mounted) return;
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
    final double fabSize = 64;
    final double iconSize = 24;
    final Color selectedColor = AppColors.primary;
    final Color unselectedColor = Colors.grey;
    return SizedBox(
      height: navBarHeight + 12, // extra for overlap shadow
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
                  _buildNavItem(0, Icons.home, 'Home', iconSize, selectedColor, unselectedColor),
                  _buildNavItem(1, Icons.search, 'Find Ride', iconSize, selectedColor, unselectedColor),
                  SizedBox(width: fabSize), // space for center button
                  _buildNavItem(3, Icons.route, 'My Trip', iconSize, selectedColor, unselectedColor),
                  _buildNavItem(4, Icons.person, 'Profile', iconSize, selectedColor, unselectedColor),
                ],
              ),
            ),
          ),
          // Center circular button for Offer Ride
          Positioned(
            top: -fabSize / 2 + 12,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                elevation: 8,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => _onItemTapped(2),
                  borderRadius: BorderRadius.circular(fabSize / 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: fabSize,
                    height: fabSize,
                    decoration: BoxDecoration(
                      color: _selectedIndex == 2 ? selectedColor : Colors.green[300],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: selectedColor.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
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
        width: 64,
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

class _HomePage extends StatelessWidget {
  const _HomePage();
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return SingleChildScrollView(
      child: Column(
        children: [
          // Verification prompt
          if (user != null) VerificationPrompt(user: user),
          // Welcome text
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'Welcome, ${user?.fullName ?? "User"}!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          // Three card buttons
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: _buildActionCard(
                  context,
                  'My Trip',
                  Icons.route,
                  AppColors.primary,
                  () => _navigateToMyRide(context),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _buildActionCard(
                  context,
                  'Find Ride',
                  Icons.search,
                  Colors.blue,
                  () => _navigateToFindRide(context),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _buildActionCard(
                  context,
                  'Offer Ride',
                  Icons.add_circle,
                  Colors.green,
                  () => _navigateToOfferRide(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                _getDescription(title),
                style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDescription(String title) {
    switch (title) {
      case 'My Ride':
        return 'View your trips';
      case 'Find Ride':
        return 'Search for rides';
      case 'Offer Ride':
        return 'Create a ride';
      default:
        return '';
    }
  }

  void _navigateToMyRide(BuildContext context) {
    // Navigate to My Trip page (index 3 in the bottom navigation)
    final userDashboard = context.findAncestorStateOfType<_UserDashboardState>();
    if (userDashboard != null) {
      userDashboard._onItemTapped(3);
    }
  }

  void _navigateToFindRide(BuildContext context) {
    // Navigate to Find Ride page (index 1 in the bottom navigation)
    final userDashboard = context.findAncestorStateOfType<_UserDashboardState>();
    if (userDashboard != null) {
      userDashboard._onItemTapped(1);
    }
  }

  void _navigateToOfferRide(BuildContext context) {
    // Navigate to Offer Ride page (index 2 in the bottom navigation)
    final userDashboard = context.findAncestorStateOfType<_UserDashboardState>();
    if (userDashboard != null) {
      userDashboard._onItemTapped(2);
    }
  }
}

class _FindRidePage extends StatelessWidget {
  const _FindRidePage();
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final authProvider = context.watch<AuthProvider>();
    final isEmailVerified = authProvider.isEmailVerified();
    final isPhoneVerified = user?.isPhoneVerified ?? false;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Verification prompt (if email or phone not verified)
          if (user != null && (!isEmailVerified || !isPhoneVerified))
            VerificationPrompt(user: user),
          
          // Document validation prompt (if IC not verified)
          if (user != null) DocumentValidationPrompt(
            user: user,
            onNavigateToProfile: () {
              // Navigate to Profile page with IC scroll
              final userDashboard = context.findAncestorStateOfType<_UserDashboardState>();
              if (userDashboard != null) {
                userDashboard._navigateToProfileWithICScroll();
              }
            },
          ),
          
          // Main Find Ride content (only show if all verifications are complete)
          if (isEmailVerified && isPhoneVerified)
            StreamBuilder<DocumentSnapshot?>(
              stream: FirebaseFirestore.instance
                  .collection('ic')
                  .where('uid', isEqualTo: user?.uid)
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .snapshots()
                  .map((querySnapshot) => querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null),
              builder: (context, snapshot) {
                String? icStatus;
                if (snapshot.hasData && snapshot.data != null) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null) {
                    icStatus = data['status'] as String?;
                  }
                }
                
                final isICVerified = icStatus == 'verified';
                
                if (isICVerified) {
                  return Center(
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.search, size: 48, color: AppColors.primary),
                            SizedBox(height: 16),
                            Text(
                              'Find Ride',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text('Search for available carpools.'),
                          ],
                        ),
                      ),
                    ),
                  );
                } else {
                  return Center(
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock,
                              size: 48,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Verification Required',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please complete all verifications above to access Find Ride features.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              },
            )
          else
            // Show message when email/phone verifications are pending
            Center(
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock,
                        size: 48,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Verification Required',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please complete all verifications above to access Find Ride features.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OfferRidePage extends StatelessWidget {
  const _OfferRidePage();
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final authProvider = context.watch<AuthProvider>();
    final isEmailVerified = authProvider.isEmailVerified();
    final isPhoneVerified = user?.isPhoneVerified ?? false;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Verification prompt (if email or phone not verified)
          if (user != null && (!isEmailVerified || !isPhoneVerified))
            VerificationPrompt(user: user),
          
          // Document validation prompt (if IC or License not verified)
          if (user != null) DocumentValidationPrompt(
            user: user,
            showLicense: true,
            onNavigateToProfile: () {
              // Navigate to Profile page with IC scroll
              final userDashboard = context.findAncestorStateOfType<_UserDashboardState>();
              if (userDashboard != null) {
                userDashboard._navigateToProfileWithICScroll();
              }
            },
            onNavigateToLicense: () {
              // Navigate to Profile page with License scroll
              final userDashboard = context.findAncestorStateOfType<_UserDashboardState>();
              if (userDashboard != null) {
                userDashboard._navigateToProfileWithLicenseScroll();
              }
            },
          ),
          
          // Main Offer Ride content (only show if all verifications are complete)
          if (isEmailVerified && isPhoneVerified)
            StreamBuilder<DocumentSnapshot?>(
              stream: FirebaseFirestore.instance
                  .collection('ic')
                  .where('uid', isEqualTo: user?.uid)
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .snapshots()
                  .map((querySnapshot) => querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null),
              builder: (context, icSnapshot) {
                String? icStatus;
                if (icSnapshot.hasData && icSnapshot.data != null) {
                  final data = icSnapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null) {
                    icStatus = data['status'] as String?;
                  }
                }
                
                return StreamBuilder<DocumentSnapshot?>(
                  stream: FirebaseFirestore.instance
                      .collection('license')
                      .where('uid', isEqualTo: user?.uid)
                      .orderBy('createdAt', descending: true)
                      .limit(1)
                      .snapshots()
                      .map((querySnapshot) => querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null),
                  builder: (context, licenseSnapshot) {
                    String? licenseStatus;
                    if (licenseSnapshot.hasData && licenseSnapshot.data != null) {
                      final data = licenseSnapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null) {
                        licenseStatus = data['status'] as String?;
                      }
                    }
                    
                    final isICVerified = icStatus == 'verified';
                    final isLicenseVerified = licenseStatus == 'verified';
                    
                    if (isICVerified && isLicenseVerified) {
                      return Column(
                        children: [
                          // Offer Ride Button
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 20),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CreateRideScreen(user: user!),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_circle, color: Colors.white),
                              label: const Text(
                                'Offer Ride',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                          
                          // Search Bar
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search your rides...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.primary),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onChanged: (value) {
                                // TODO: Implement search functionality
                              },
                            ),
                          ),
                          
                          // My Offered Rides Section
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'My Offered Rides',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Rides List
                          user?.uid != null
                              ? StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('rides')
                                      .where('uid', isEqualTo: user!.uid)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      );
                                    }
                                    
                                    // If there's an error or no data, treat it as empty rides
                                    final rides = snapshot.data?.docs ?? [];
                                    
                                    if (rides.isEmpty) {
                                      return Center(
                                        child: Card(
                                          elevation: 3,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(24.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.directions_car, size: 48, color: Colors.grey[400]),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'No Rides Offered Yet',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Start offering rides to help others and earn money!',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    
                                    return ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: rides.length,
                                      itemBuilder: (context, index) {
                                        final ride = rides[index].data() as Map<String, dynamic>;
                                        final title = ride['title'] as String? ?? 'Untitled Ride';
                                        final start = ride['start'] as String? ?? 'Unknown';
                                        final end = ride['end'] as String? ?? 'Unknown';
                                        final vehicle = ride['vehicle'] as String? ?? 'Unknown Vehicle';
                                        final datetime = ride['datetime'] as Timestamp?;
                                        final fare = ride['fare'] as num? ?? 0;
                                        final passengers = ride['passengers'] as List<dynamic>? ?? [];
                                        final createdAt = ride['createdAt'] as Timestamp?;
                                        
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          child: Card(
                                            elevation: 4,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          title,
                                                          style: const TextStyle(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.primary,
                                                          borderRadius: BorderRadius.circular(20),
                                                        ),
                                                        child: Text(
                                                          'RM ${fare.toStringAsFixed(2)}',
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  _buildInfoRow(Icons.location_on, 'From', start),
                                                  const SizedBox(height: 8),
                                                  _buildInfoRow(Icons.location_on_outlined, 'To', end),
                                                  const SizedBox(height: 8),
                                                  _buildInfoRow(Icons.directions_car, 'Vehicle', vehicle),
                                                  const SizedBox(height: 8),
                                                  if (datetime != null)
                                                    _buildInfoRow(
                                                      Icons.schedule,
                                                      'Departure',
                                                      DateFormat('MMM dd, yyyy - HH:mm').format(datetime.toDate()),
                                                    ),
                                                  const SizedBox(height: 8),
                                                  _buildInfoRow(
                                                    Icons.people,
                                                    'Passengers',
                                                    '${passengers.length} booked',
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: OutlinedButton.icon(
                                                          onPressed: () {
                                                            // TODO: Edit ride functionality
                                                          },
                                                          icon: const Icon(Icons.edit, size: 16),
                                                          label: const Text('Edit'),
                                                          style: OutlinedButton.styleFrom(
                                                            foregroundColor: AppColors.primary,
                                                            side: BorderSide(color: AppColors.primary),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: ElevatedButton.icon(
                                                          onPressed: () {
                                                            // TODO: View details functionality
                                                          },
                                                          icon: const Icon(Icons.visibility, size: 16),
                                                          label: const Text('View'),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: AppColors.primary,
                                                            foregroundColor: Colors.white,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                )
                              : const Center(
                                  child: Text(
                                    'User not found',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                        ],
                      );
                    } else {
                      return Center(
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock,
                                  size: 48,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Verification Required',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please complete all verifications above to access Offer Ride features.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            )
          else
            // Show message when email/phone verifications are pending
            Center(
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock,
                        size: 48,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Verification Required',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please complete all verifications above to access Offer Ride features.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MyTripPage extends StatelessWidget {
  const _MyTripPage();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.route, size: 48, color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'My Trip',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('View your trip history and current rides.'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  final bool scrollToIC;
  final bool scrollToLicense;

  const _ProfilePage({this.scrollToIC = false, this.scrollToLicense = false});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ProfileSection(
      user: user,
      isPhoneVerified: user.isPhoneVerified ?? false,
      licenseStatus: null,
      icStatus: null,
      scrollToIC: scrollToIC,
      scrollToLicense: scrollToLicense,
      onEdit: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditProfileScreen(user: user),
          ),
        );
      },
      onResetPassword: () async {
        try {
          await AuthService().resetPassword(user.email);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset link sent to your email.'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send reset link: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }
} 