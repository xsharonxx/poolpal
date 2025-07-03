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
import 'location_picker_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';
import '../../widgets/ride_card.dart';
import 'ride_details_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/status_update_service.dart';

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
                        StatusUpdateService.dispose();
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
      case 'My Trip':
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

class _FindRidePage extends StatefulWidget {
  const _FindRidePage();

  @override
  State<_FindRidePage> createState() => _FindRidePageState();
}

class _FindRidePageState extends State<_FindRidePage> {
  String _searchQuery = '';
  String _sortBy = 'datetime'; // 'datetime' or 'recently_added'
  bool _sortAscending = true; // true for ascending, false for descending
  String? _selectedLocation;
  LatLng? _selectedLatLng;
  DateTime? _selectedDate;
  bool _locationInitialized = false;

  @override
  void initState() {
    super.initState();
    _initUserLocation();
    // Initialize status update service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StatusUpdateService.updateAllStatuses();
      StatusUpdateService.setupRealTimeListeners();
    });
  }

  Future<void> _initUserLocation() async {
    if (_locationInitialized) return;
    _locationInitialized = true;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return;
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng latLng = LatLng(position.latitude, position.longitude);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      String address = placemarks.isNotEmpty
        ? [placemarks.first.name, placemarks.first.locality, placemarks.first.administrativeArea, placemarks.first.country].where((e) => e != null && e.isNotEmpty).join(', ')
        : 'Current Location';
      if (mounted && _selectedLatLng == null && _selectedLocation == null) {
        setState(() {
          _selectedLatLng = latLng;
          _selectedLocation = address;
        });
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final authProvider = context.watch<AuthProvider>();
    final isEmailVerified = authProvider.isEmailVerified();
    final isPhoneVerified = user?.isPhoneVerified ?? false;

    return StreamBuilder<DocumentSnapshot?> (
      stream: (user != null)
        ? FirebaseFirestore.instance
                  .collection('ic')
            .where('uid', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .snapshots()
            .map((querySnapshot) => querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null)
        : const Stream.empty(),
              builder: (context, snapshot) {
                String? icStatus;
                if (snapshot.hasData && snapshot.data != null) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null) {
                    icStatus = data['status'] as String?;
                  }
                }
                final isICVerified = icStatus == 'verified';
        final isFullyVerified = user != null && isEmailVerified && isPhoneVerified && isICVerified;
        if (!isFullyVerified) {
          // Show only verification/document prompts and the Verification Required card, scrollable and centered
          return Center(
              child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user != null && (!isEmailVerified || !isPhoneVerified))
                      VerificationPrompt(user: user),
                    if (user != null)
                      DocumentValidationPrompt(
                        user: user,
                        onNavigateToProfile: () {
                          final userDashboard = context.findAncestorStateOfType<_UserDashboardState>();
                          if (userDashboard != null) {
                            userDashboard._navigateToProfileWithICScroll();
                          }
                        },
                      ),
                    // Verification Required Card (no extra top padding)
                    Card(
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
                          ],
                      ),
                    ),
                  );
        }
        // All verifications complete: show features
        return Column(
          children: [
            // Location Bar
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationPickerScreen(
                        title: 'Select Location',
                        initialLocation: _selectedLocation,
                        initialLatLng: _selectedLatLng,
                      ),
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      _selectedLocation = result['location'];
                      _selectedLatLng = result['latLng'] as LatLng?;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedLocation ?? 'Use Current Location',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            // Search Bar + Calendar
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  // Search Bar (Expanded)
                  Expanded(
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search rides...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Calendar Icon
                  GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? now,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedDate != null ? AppColors.primary : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.calendar_today,
                        color: _selectedDate != null ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                  if (_selectedDate != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = null;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                ],
              ),
            ),
            // Rides List with Pull to Refresh
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                child: StreamBuilder<QuerySnapshot>(
                  stream: _buildRidesStream(user?.uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    final rides = snapshot.data?.docs ?? [];
                    final filteredRides = _filterRides(rides);
                    if (filteredRides.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.only(top: 8),
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
              child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: const Padding(
                                padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                                    Icon(Icons.search_off, size: 48, color: Colors.grey),
                                    SizedBox(height: 16),
                      Text(
                                      'No rides available',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 8),
                      Text(
                                      'Check back later for new rides or try adjusting your search.',
                        textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                        ),
                      ),
                    ],
                      );
                    }
                    return ListView.builder(
                      itemCount: filteredRides.length,
                      itemBuilder: (context, index) {
                        final ride = filteredRides[index];
                        final data = ride.data() as Map<String, dynamic>;
                        final user = context.watch<AuthProvider>().user;
                        final uid = user?.uid;
                        final isMyOfferedRide = data['uid'] == uid;
                        return RideCard(
                          data: data,
                          rideId: ride.id,
                          showOfferedUser: false,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RideDetailsScreen(
                                  rideId: ride.id,
                                  mode: RideDetailsMode.find,
                                  hideApplications: !isMyOfferedRide,
                                ),
                              ),
                            );
                          },
                          isMyOfferedRide: false,
                          hideApplications: true,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Stream<QuerySnapshot> _buildRidesStream(String? currentUserId) {
    Query query = FirebaseFirestore.instance.collection('rides')
        .where('status', isEqualTo: 'active');

    // Apply sorting
    if (_sortBy == 'datetime') {
      query = query.orderBy('datetime', descending: !_sortAscending);
    } else if (_sortBy == 'recently_added') {
      query = query.orderBy('created_at', descending: !_sortAscending);
    }

    return query.snapshots();
  }

  List<QueryDocumentSnapshot> _filterRides(List<QueryDocumentSnapshot> rides) {
    final user = context.watch<AuthProvider>().user;
    final currentUserId = user?.uid;
    // First filter out current user's rides and only active rides
    final otherUsersRides = rides.where((ride) {
      final data = ride.data() as Map<String, dynamic>;
      return data['uid'] != currentUserId && data['status'] == 'active';
    }).toList();
    
    // Then apply search filter if needed
    List<QueryDocumentSnapshot> filtered = otherUsersRides;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((ride) {
        final data = ride.data() as Map<String, dynamic>;
        final title = (data['title'] ?? '').toString().toLowerCase();
        final startLocation = (data['start_location']?['name'] ?? '').toString().toLowerCase();
        final endLocation = (data['end_location']?['name'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return title.contains(query) ||
               startLocation.contains(query) ||
               endLocation.contains(query);
      }).toList();
    }
    // Date filter
    if (_selectedDate != null) {
      filtered = filtered.where((ride) {
        final data = ride.data() as Map<String, dynamic>;
        final dt = data['datetime'] is Timestamp ? (data['datetime'] as Timestamp).toDate() : null;
        if (dt == null) return false;
        return dt.year == _selectedDate!.year && dt.month == _selectedDate!.month && dt.day == _selectedDate!.day;
      }).toList();
    }
    // Sorting logic
    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      if (_selectedLatLng != null) {
        // Sort by distance, then by datetime
        final aLat = aData['start_location']?['lat'] as double? ?? aData['start_location']?['latitude'] as double?;
        final aLng = aData['start_location']?['lng'] as double? ?? aData['start_location']?['longitude'] as double?;
        final bLat = bData['start_location']?['lat'] as double? ?? bData['start_location']?['latitude'] as double?;
        final bLng = bData['start_location']?['lng'] as double? ?? bData['start_location']?['longitude'] as double?;
        double aDist = double.infinity;
        double bDist = double.infinity;
        if (aLat != null && aLng != null) {
          aDist = _calculateDistance(_selectedLatLng!.latitude, _selectedLatLng!.longitude, aLat, aLng);
        }
        if (bLat != null && bLng != null) {
          bDist = _calculateDistance(_selectedLatLng!.latitude, _selectedLatLng!.longitude, bLat, bLng);
        }
        if (aDist != bDist) {
          return aDist.compareTo(bDist);
        }
        // If distance is the same, sort by datetime ascending
        final aTime = aData['datetime'] is Timestamp ? (aData['datetime'] as Timestamp).toDate() : null;
        final bTime = bData['datetime'] is Timestamp ? (bData['datetime'] as Timestamp).toDate() : null;
        if (aTime != null && bTime != null) {
          return aTime.compareTo(bTime);
        }
        return 0;
      } else {
        // No location: sort by datetime ascending
        final aTime = aData['datetime'] is Timestamp ? (aData['datetime'] as Timestamp).toDate() : null;
        final bTime = bData['datetime'] is Timestamp ? (bData['datetime'] as Timestamp).toDate() : null;
        if (aTime != null && bTime != null) {
          return aTime.compareTo(bTime);
        }
        return 0;
      }
    });
    return filtered;
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371; // km
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180.0;
    final dLng = (lng2 - lng1) * 3.141592653589793 / 180.0;
    final a =
        0.5 -
        (cos(dLat) / 2) +
        cos(lat1 * 3.141592653589793 / 180.0) *
            cos(lat2 * 3.141592653589793 / 180.0) *
            (1 - cos(dLng)) / 2;
    return R * 2 * asin(sqrt(a));
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else {
        return 'Invalid time';
      }
      
      return DateFormat('MMM dd, yyyy - HH:mm').format(dateTime);
    } catch (e) {
      return 'Invalid time';
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
}

class _OfferRidePage extends StatefulWidget {
  const _OfferRidePage();

  @override
  State<_OfferRidePage> createState() => _OfferRidePageState();
}

class _OfferRidePageState extends State<_OfferRidePage> {
  String _searchQuery = '';
  String _sortBy = 'datetime'; // 'datetime' or 'recently_added'
  bool _sortAscending = true; // true for ascending, false for descending
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                          
                          // Search and Sort Section
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                          // Search Bar
                                  TextField(
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                    },
                              decoration: InputDecoration(
                                hintText: 'Search your rides...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Sort Options
                                  Row(
                                    children: [
                                      const Text('Sort by: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      // Sort Field Dropdown
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
                                              DropdownMenuItem(value: 'datetime', child: Text('Date & Time')),
                                              DropdownMenuItem(value: 'recently_added', child: Text('Recently Added')),
                                            ],
                              onChanged: (value) {
                                              setState(() {
                                                _sortBy = value!;
                                              });
                              },
                            ),
                          ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Sort Direction Button
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _sortAscending = !_sortAscending;
                                            });
                                          },
                                          icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                                          tooltip: _sortAscending ? 'Ascending' : 'Descending',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
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
                                  stream: _buildMyRidesStream(user!.uid),
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
                                    final filteredRides = _filterMyRides(rides);
                                    
                                    if (filteredRides.isEmpty) {
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
                                                  _searchQuery.isEmpty ? 'No Rides Offered Yet' : 'No Rides Found',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  _searchQuery.isEmpty 
                                                    ? 'Start offering rides to help others and earn money!'
                                                    : 'Try adjusting your search or filters.',
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
                                      itemCount: filteredRides.length,
                                      itemBuilder: (context, index) {
                                        final ride = filteredRides[index];
                                        final data = ride.data() as Map<String, dynamic>;
                                        final user = context.watch<AuthProvider>().user;
                                        final uid = user?.uid;
                                        final isMyOfferedRide = data['uid'] == uid;
                                        return RideCard(
                                          data: data,
                                          rideId: ride.id,
                                          showOfferedUser: false,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => RideDetailsScreen(
                                                  rideId: ride.id,
                                                  mode: RideDetailsMode.offer,
                                                  hideApplications: !isMyOfferedRide,
                                                ),
                                              ),
                                            );
                                          },
                                          isMyOfferedRide: false,
                                        );
                                      },
                                    );
                                  },
                                )
                              : const SizedBox.shrink(),
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

  Stream<QuerySnapshot> _buildMyRidesStream(String uid) {
    Query query = FirebaseFirestore.instance.collection('rides')
        .where('uid', isEqualTo: uid);

    // Apply sorting
    if (_sortBy == 'datetime') {
      query = query.orderBy('datetime', descending: !_sortAscending);
    } else if (_sortBy == 'recently_added') {
      query = query.orderBy('created_at', descending: !_sortAscending);
    }

    return query.snapshots();
  }

  List<QueryDocumentSnapshot> _filterMyRides(List<QueryDocumentSnapshot> rides) {
    // Only show active rides
    final activeRides = rides.where((ride) {
      final data = ride.data() as Map<String, dynamic>;
      return data['status'] == 'active';
    }).toList();
    if (_searchQuery.isEmpty) {
      return activeRides;
    }
    return activeRides.where((ride) {
      final data = ride.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toString().toLowerCase();
      final startLocation = (data['start_location']?['name'] ?? '').toString().toLowerCase();
      final endLocation = (data['end_location']?['name'] ?? '').toString().toLowerCase();
      final vehicle = (data['vehicle'] ?? '').toString().toLowerCase();
      final vehicleModel = (data['vehicle_model'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query) ||
             startLocation.contains(query) ||
             endLocation.contains(query) ||
             vehicle.contains(query) ||
             vehicleModel.contains(query);
    }).toList();
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else {
        return 'Invalid time';
      }
      
      return DateFormat('MMM dd, yyyy - HH:mm').format(dateTime);
    } catch (e) {
      return 'Invalid time';
    }
  }
}

class _MyTripPage extends StatefulWidget {
  const _MyTripPage();
  @override
  State<_MyTripPage> createState() => _MyTripPageState();
}

class _MyTripPageState extends State<_MyTripPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final uid = user.uid;
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: Colors.white, width: 4),
          ),
          tabs: const [
            Tab(text: 'History'),
            Tab(text: 'Trip'),
            Tab(text: 'Request'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // History Tab
              _HistoryTab(uid: uid),
              // Trips Tab
              _TripsTab(uid: uid),
              // Applications Tab
              _ApplicationsTab(uid: uid),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final String uid;
  const _HistoryTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Stream for rides offered by me (no datetime filter)
    final offeredRidesStream = FirebaseFirestore.instance
        .collection('rides')
        .where('uid', isEqualTo: uid)
        .snapshots();
    // Stream for accepted applications by me (no datetime filter)
    final acceptedAppsStream = FirebaseFirestore.instance
        .collection('applications')
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'accept')
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: offeredRidesStream,
      builder: (context, offeredSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: acceptedAppsStream,
          builder: (context, appsSnapshot) {
            if (offeredSnapshot.connectionState == ConnectionState.waiting ||
                appsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final offeredRides = offeredSnapshot.data?.docs ?? [];
            final acceptedApps = appsSnapshot.data?.docs ?? [];
            final rideIds = acceptedApps.map((app) => app['ride_id'] as String).toSet();
            return StreamBuilder<QuerySnapshot>(
              stream: rideIds.isEmpty
                  ? const Stream.empty()
                  : FirebaseFirestore.instance
                      .collection('rides')
                      .where(FieldPath.documentId, whereIn: rideIds.toList())
                      .snapshots(),
              builder: (context, ridesSnapshot) {
                if (ridesSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final acceptedRides = ridesSnapshot.data?.docs ?? [];
                // Group rides by status
                final passedRides = [...offeredRides, ...acceptedRides]
                  .where((ride) {
                    final data = ride.data() as Map<String, dynamic>;
                    return data['status'] == 'passed';
                  }).toList();
                final cancelRides = [...offeredRides, ...acceptedRides]
                  .where((ride) {
                    final data = ride.data() as Map<String, dynamic>;
                    return data['status'] == 'cancel';
                  }).toList();
                // Sort passedRides by departure datetime desc
                passedRides.sort((a, b) {
                  final aDt = a['datetime'] is Timestamp ? a['datetime'].toDate() : DateTime.tryParse(a['datetime'].toString()) ?? DateTime(1970);
                  final bDt = b['datetime'] is Timestamp ? b['datetime'].toDate() : DateTime.tryParse(b['datetime'].toString()) ?? DateTime(1970);
                  return bDt.compareTo(aDt);
                });
                // Sort cancelRides by updated_at desc
                cancelRides.sort((a, b) {
                  final aDt = a['updated_at'] is Timestamp ? a['updated_at'].toDate() : DateTime.tryParse(a['updated_at'].toString()) ?? DateTime(1970);
                  final bDt = b['updated_at'] is Timestamp ? b['updated_at'].toDate() : DateTime.tryParse(b['updated_at'].toString()) ?? DateTime(1970);
                  return bDt.compareTo(aDt);
                });
                if (passedRides.isEmpty && cancelRides.isEmpty) {
                  return const Center(child: Text('No history found.'));
                }
                return ListView(
                  children: [
                    if (passedRides.isNotEmpty)
                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: false,
                          leading: const Icon(Icons.check_circle, color: Colors.green),
                          title: const Text('Passed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                          children: passedRides.map((ride) {
                            final rideData = ride.data() as Map<String, dynamic>;
                            final isMyOfferedRide = rideData['uid'] == uid;
                            return RideCard(
                              data: rideData,
                              rideId: ride.id,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RideDetailsScreen(
                                      rideId: ride.id,
                                      mode: isMyOfferedRide ? RideDetailsMode.offer : RideDetailsMode.find,
                                      hideEditCancel: isMyOfferedRide,
                                      hideJoinButton: !isMyOfferedRide,
                                      hideApplications: true,
                                    ),
                                  ),
                                );
                              },
                              showOfferedUser: !isMyOfferedRide,
                              isMyOfferedRide: isMyOfferedRide,
                              hideApplications: true,
                            );
                          }).toList(),
                        ),
                      ),
                    // Always show Cancel section
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        leading: const Icon(Icons.cancel, color: Colors.red),
                        title: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                        children: cancelRides.isNotEmpty
                          ? cancelRides.map((ride) {
                              final rideData = ride.data() as Map<String, dynamic>;
                              final isMyOfferedRide = rideData['uid'] == uid;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RideCard(
                                    data: rideData,
                                    rideId: ride.id,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RideDetailsScreen(
                                            rideId: ride.id,
                                            mode: isMyOfferedRide ? RideDetailsMode.offer : RideDetailsMode.find,
                                            hideEditCancel: isMyOfferedRide,
                                            hideJoinButton: !isMyOfferedRide,
                                            hideApplications: true,
                                          ),
                                        ),
                                      );
                                    },
                                    showOfferedUser: !isMyOfferedRide,
                                    isMyOfferedRide: isMyOfferedRide,
                                    hideApplications: true,
                                    extraInfo: _requestInfoRow(
                                      'Updated At',
                                      _formatDate(rideData['updated_at'], withTime: true),
                                      Colors.red,
                                    ),
                                  ),
                                ],
                              );
                            }).toList()
                          : [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(child: Text('No canceled trips.')),
                              ),
                            ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _TripsTab extends StatelessWidget {
  final String uid;
  const _TripsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    // Stream for rides offered by me (only active ones)
    final offeredRidesStream = FirebaseFirestore.instance
        .collection('rides')
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .snapshots();
    // Stream for accepted applications by me
    final acceptedAppsStream = FirebaseFirestore.instance
        .collection('applications')
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'accept')
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: offeredRidesStream,
      builder: (context, offeredSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: acceptedAppsStream,
          builder: (context, appsSnapshot) {
            if (offeredSnapshot.connectionState == ConnectionState.waiting ||
                appsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final offeredRides = offeredSnapshot.data?.docs ?? [];
            final acceptedApps = appsSnapshot.data?.docs ?? [];
            final rideIds = acceptedApps.map((app) => app['ride_id'] as String).toSet();
            return StreamBuilder<QuerySnapshot>(
              stream: rideIds.isEmpty
                  ? const Stream.empty()
                  : FirebaseFirestore.instance
                      .collection('rides')
                      .where(FieldPath.documentId, whereIn: rideIds.toList())
                      .where('status', isEqualTo: 'active')
                      .snapshots(),
              builder: (context, ridesSnapshot) {
                if (ridesSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final acceptedRides = ridesSnapshot.data?.docs ?? [];
                // Combine and sort by departure datetime asc
                final allRides = [...offeredRides, ...acceptedRides];
                allRides.sort((a, b) {
                  final aDt = a['datetime'] is Timestamp ? a['datetime'].toDate() : DateTime.tryParse(a['datetime'].toString()) ?? DateTime(1970);
                  final bDt = b['datetime'] is Timestamp ? b['datetime'].toDate() : DateTime.tryParse(b['datetime'].toString()) ?? DateTime(1970);
                  return aDt.compareTo(bDt);
                });
                if (allRides.isEmpty) {
                  return const Center(child: Text('No trips found.'));
                }
                return ListView.builder(
                  itemCount: allRides.length,
                  itemBuilder: (context, index) {
                    final ride = allRides[index];
                    final rideData = ride.data() as Map<String, dynamic>;
                    final isMyOfferedRide = rideData['uid'] == uid;
                    return RideCard(
                      data: rideData,
                      rideId: ride.id,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RideDetailsScreen(
                              rideId: ride.id,
                              mode: isMyOfferedRide
                                  ? RideDetailsMode.offer
                                  : RideDetailsMode.find,
                              hideJoinButton: !isMyOfferedRide,
                              hideApplications: !isMyOfferedRide,
                            ),
                          ),
                        );
                      },
                      showOfferedUser: !isMyOfferedRide,
                      isMyOfferedRide: isMyOfferedRide,
                      hideApplications: !isMyOfferedRide,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ApplicationsTab extends StatelessWidget {
  final String uid;
  const _ApplicationsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    final appsStream = FirebaseFirestore.instance
        .collection('applications')
        .where('uid', isEqualTo: uid)
        .snapshots();
    return StreamBuilder<QuerySnapshot>(
      stream: appsStream,
      builder: (context, appsSnapshot) {
        if (appsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final apps = appsSnapshot.data?.docs ?? [];
        final pending = apps.where((app) => app['status'] == 'pending').toList();
        final rejected = apps.where((app) => app['status'] == 'reject').toList();
        // Sort pending by created_at asc
        pending.sort((a, b) {
          final aDt = a['created_at'] is Timestamp ? a['created_at'].toDate() : DateTime.tryParse(a['created_at'].toString()) ?? DateTime(1970);
          final bDt = b['created_at'] is Timestamp ? b['created_at'].toDate() : DateTime.tryParse(b['created_at'].toString()) ?? DateTime(1970);
          return aDt.compareTo(bDt);
        });
        // Sort rejected by updated_at desc
        rejected.sort((a, b) {
          final aDt = a['updated_at'] is Timestamp ? a['updated_at'].toDate() : DateTime.tryParse(a['updated_at'].toString()) ?? DateTime(1970);
          final bDt = b['updated_at'] is Timestamp ? b['updated_at'].toDate() : DateTime.tryParse(b['updated_at'].toString()) ?? DateTime(1970);
          return bDt.compareTo(aDt);
        });
        final allApps = [...pending, ...rejected];
        if (allApps.isEmpty) {
          return const Center(child: Text('No requests found.'));
        }
        return ListView(
          children: [
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                leading: const Icon(Icons.hourglass_top, color: Colors.orange),
                title: Text('Pending', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange[800])),
                children: pending.isNotEmpty
                    ? pending.map((app) => FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('rides').doc(app['ride_id']).get(),
                        builder: (context, rideSnapshot) {
                          if (!rideSnapshot.hasData || !rideSnapshot.data!.exists) {
                            return const SizedBox.shrink();
                          }
                          final rideData = rideSnapshot.data!.data() as Map<String, dynamic>;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RideCard(
                                data: rideData,
                                rideId: app['ride_id'],
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RideDetailsScreen(
                                        rideId: app['ride_id'],
                                        mode: RideDetailsMode.find,
                                        hideJoinButton: true,
                                        hideApplications: true,
                                      ),
                                    ),
                                  );
                                },
                                showOfferedUser: true,
                                extraInfo: _requestInfoRow(
                                  'Request At',
                                  _formatDate(app['created_at'], withTime: true),
                                  Colors.orange[800]!,
                                ),
                              ),
                            ],
                          );
                        },
                      )).toList()
                    : [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Center(child: Text('No pending requests.')),
                        ),
                      ],
              ),
            ),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: Text('Rejected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red[800])),
                children: rejected.isNotEmpty
                    ? rejected.map((app) => FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('rides').doc(app['ride_id']).get(),
                        builder: (context, rideSnapshot) {
                          if (!rideSnapshot.hasData || !rideSnapshot.data!.exists) {
                            return const SizedBox.shrink();
                          }
                          final rideData = rideSnapshot.data!.data() as Map<String, dynamic>;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RideCard(
                                data: rideData,
                                rideId: app['ride_id'],
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RideDetailsScreen(
                                        rideId: app['ride_id'],
                                        mode: RideDetailsMode.find,
                                        hideJoinButton: true,
                                        hideApplications: true,
                                      ),
                                    ),
                                  );
                                },
                                showOfferedUser: true,
                                extraInfo: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _requestInfoRow(
                                      'Request At',
                                      _formatDate(app['created_at'], withTime: true),
                                      Colors.red[800]!,
                                    ),
                                    _requestInfoRow(
                                      'Updated At',
                                      _formatDate(app['updated_at'], withTime: true),
                                      Colors.red[800]!,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      )).toList()
                    : [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Center(child: Text('No rejected requests.')),
                        ),
                      ],
              ),
            ),
          ],
        );
      },
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
        } catch (e) {
        }
      },
    );
  }
}

Widget _requestInfoRow(String label, dynamic value, Color color) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Expanded(child: Text(value != null && value.toString().isNotEmpty ? value.toString() : '-', style: TextStyle(color: color))),
      ],
    ),
  );
}

String _formatDate(dynamic dateVal, {bool withTime = false}) {
  if (dateVal == null || dateVal.toString().isEmpty) return '-';
  try {
    DateTime dt;
    if (dateVal is Timestamp) {
      dt = dateVal.toDate();
    } else if (dateVal is DateTime) {
      dt = dateVal;
    } else {
      dt = DateTime.parse(dateVal.toString());
    }
    return withTime
        ? DateFormat('yyyy-MM-dd HH:mm').format(dt)
        : DateFormat('MMM d, yyyy').format(dt);
  } catch (e) {
    return dateVal.toString();
  }
} 