import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'create_ride_screen.dart';
import 'ride_applications_screen.dart';

// Enum for screen mode
enum RideDetailsMode { review, find, offer }

class RideDetailsScreen extends StatefulWidget {
  final String rideId;
  final RideDetailsMode mode;
  final bool hideJoinButton;
  final bool hideEditCancel;
  final bool hideApplications;
  const RideDetailsScreen({
    Key? key,
    required this.rideId,
    required this.mode,
    this.hideJoinButton = false,
    this.hideEditCancel = false,
    this.hideApplications = false,
  }) : super(key: key);

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  String? _selectedMarkerId;
  List<LatLng> _routePoints = [];
  bool _isLoadingJoin = false;
  bool _isLoadingRoute = false;
  bool _routeRequested = false;
  LatLng? _lastStartLatLng;
  LatLng? _lastEndLatLng;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _getRoute(LatLng startLatLng, LatLng endLatLng) async {
    setState(() { _isLoadingRoute = true; });
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${startLatLng.latitude},${startLatLng.longitude}'
        '&destination=${endLatLng.latitude},${endLatLng.longitude}'
        '&key=AIzaSyDNM21ltVcIVErtC6GkPg0QK-TW-6WLu8w'
      );
      final response = await http.get(url);
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final points = route['overview_polyline']['points'];
        setState(() {
        _routePoints = _decodePolyline(points);
          _isLoadingRoute = false;
        });
      } else {
        setState(() {
          _routePoints = [startLatLng, endLatLng];
          _isLoadingRoute = false;
        });
      }
    } catch (e) {
      setState(() {
        _routePoints = [startLatLng, endLatLng];
        _isLoadingRoute = false;
      });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      final p = LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
      poly.add(p);
    }
    return poly;
  }

  double _getZoomLevel(LatLng start, LatLng end) {
    final distance = _calculateDistance(start.latitude, start.longitude, end.latitude, end.longitude);
    if (distance < 1) {
      return 16;
    } else if (distance < 5) {
      return 14;
    } else if (distance < 20) {
      return 12;
    } else if (distance < 50) {
      return 10;
    } else {
      return 8;
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;
    final double dLat = _deg2rad(lat2 - lat1);
    final double dLon = _deg2rad(lon2 - lon1);
    final double a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
        (sin(dLon / 2) * sin(dLon / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distance = R * c;
    return distance;
  }

  double _deg2rad(double deg) {
    return deg * (pi / 180);
  }

  LatLng _getCenterPoint(LatLng start, LatLng end) {
    return LatLng(
      (start.latitude + end.latitude) / 2,
      (start.longitude + end.longitude) / 2,
    );
  }

  String _formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      DateTime dt = DateTime.parse(dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr);
      return DateFormat('MMMM d, yyyy').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots(),
      builder: (context, rideSnapshot) {
        if (!rideSnapshot.hasData || !rideSnapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ride Details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final rideData = rideSnapshot.data!.data() as Map<String, dynamic>;
        final int capacity = (rideData['capacity'] as num?)?.toInt() ?? 0;
        final String title = rideData['title'] ?? 'Untitled Ride';
        final String startLocation = rideData['start_location']?['name'] ?? 'Unknown';
        final String endLocation = rideData['end_location']?['name'] ?? 'Unknown';
        final String vehicle = rideData['vehicle'] ?? 'Unknown';
        final String vehicleModel = rideData['vehicle_model'] ?? 'Unknown';
        final double fare = (rideData['fare'] as num?)?.toDouble() ?? 0.0;
        final Timestamp? departureTimestamp = rideData['datetime'] as Timestamp?;
        final DateTime? departureDateTime = departureTimestamp?.toDate();
        final LatLng? startLatLng = (rideData['start_location'] != null && rideData['start_location']['latitude'] != null && rideData['start_location']['longitude'] != null)
          ? LatLng((rideData['start_location']['latitude'] as num).toDouble(), (rideData['start_location']['longitude'] as num).toDouble())
          : null;
        final LatLng? endLatLng = (rideData['end_location'] != null && rideData['end_location']['latitude'] != null && rideData['end_location']['longitude'] != null)
          ? LatLng((rideData['end_location']['latitude'] as num).toDouble(), (rideData['end_location']['longitude'] as num).toDouble())
          : null;

        // Route calculation logic
        if (startLatLng != null && endLatLng != null) {
          // If start or end changes, reset route and fetch again
          if (_lastStartLatLng == null || _lastEndLatLng == null ||
              _lastStartLatLng != startLatLng || _lastEndLatLng != endLatLng) {
            _lastStartLatLng = startLatLng;
            _lastEndLatLng = endLatLng;
            _routePoints = [];
            _isLoadingRoute = false;
            _routeRequested = false;
          }
          if (!_routeRequested) {
            _routeRequested = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _getRoute(startLatLng, endLatLng);
            });
          }
        }

        final currentUser = context.read<AuthProvider>().user;
        final isMyOfferedRide = rideData['uid'] == currentUser?.uid;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
            .collection('applications')
            .where('ride_id', isEqualTo: widget.rideId)
            .where('status', whereIn: ['pending', 'accept'])
            .snapshots(),
          builder: (context, appSnapshot) {
            final docs = appSnapshot.data?.docs ?? [];
            int booked = docs.length; // both pending and accept
            int remainingSeats = capacity - booked;
            int applicationsCount = docs.where((doc) => doc['status'] == 'pending').length;
            // Count applications excluding 'rejected'
            int nonRejectedApplications = docs.where((doc) => doc['status'] != 'rejected').length;
            // Join/cancel/edit logic
            Future<void> handleJoin() async {
              setState(() { _isLoadingJoin = true; });
              try {
                final userId = context.read<AuthProvider>().user?.uid;
                if (userId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You must be logged in to join a ride.')),
                  );
                  return;
                }
                final applicationsSnapshot = await FirebaseFirestore.instance
                  .collection('applications')
                  .where('ride_id', isEqualTo: widget.rideId)
                  .where('status', whereIn: ['pending', 'accept'])
                  .get();
                final userApplication = applicationsSnapshot.docs.where((doc) => doc['uid'] == userId).toList();
                if (userApplication.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You have already applied for this ride.')),
                  );
                  return;
                }
                if (applicationsSnapshot.docs.length < capacity) {
                  await FirebaseFirestore.instance.collection('applications').add({
                    'ride_id': widget.rideId,
                    'uid': userId,
                    'created_at': FieldValue.serverTimestamp(),
                    'status': 'pending',
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Application submitted!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ride is full.')),
                  );
                }
              } finally {
                if (mounted) setState(() { _isLoadingJoin = false; });
              }
            }
            return Scaffold(
              appBar: AppBar(
                title: Text(widget.mode == RideDetailsMode.review ? 'Review Ride' : 'Ride Details'),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              body: Stack(
                children: [
                  if (startLatLng != null && endLatLng != null) ...[
                    (() {
                      return const SizedBox.shrink();
                    })(),
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _getCenterPoint(startLatLng!, endLatLng!),
                        zoom: _getZoomLevel(startLatLng!, endLatLng!),
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('start'),
                          position: startLatLng!,
                          infoWindow: const InfoWindow(title: 'Start Location'),
                          onTap: () { setState(() { _selectedMarkerId = 'start'; }); },
                        ),
                        Marker(
                          markerId: const MarkerId('end'),
                          position: endLatLng!,
                          infoWindow: const InfoWindow(title: 'End Location'),
                          onTap: () { setState(() { _selectedMarkerId = 'end'; }); },
                        ),
                      },
                      polylines: _routePoints.isNotEmpty
                        ? {
                          Polyline(
                            polylineId: const PolylineId('route'),
                            points: _routePoints,
                            color: Colors.blue,
                            width: 4,
                          ),
                        }
                        : {},
                      onTap: (_) { setState(() { _selectedMarkerId = null; }); },
                      zoomControlsEnabled: false,
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      myLocationButtonEnabled: false,
                      myLocationEnabled: false,
                    ),
                  ],
                  if (_isLoadingRoute)
                    Container(
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
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  if (_selectedMarkerId != null && startLatLng != null && endLatLng != null)
                    Positioned(
                      top: 32,
                      right: 24,
                      child: FloatingActionButton(
                        onPressed: () {
                          final LatLng destination = _selectedMarkerId == 'start' ? startLatLng! : endLatLng!;
                          _openGoogleMaps(destination);
                        },
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                        mini: true,
                        child: const Icon(Icons.navigation),
                      ),
                    ),
                  DraggableScrollableSheet(
                    initialChildSize: 0.25,
                    minChildSize: 0.25,
                    maxChildSize: 0.85,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, -2),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              if (!isMyOfferedRide) ...[
                                const SizedBox(height: 24),
                                FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance.collection('users').doc(rideData['uid']).get(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData || !snapshot.data!.exists) {
                                      return const SizedBox.shrink();
                                    }
                                    final driverData = snapshot.data!.data() as Map<String, dynamic>;
                                    return Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                if (driverData['photoUrl'] != null && driverData['photoUrl'].toString().isNotEmpty)
                                                  CircleAvatar(
                                                    radius: 32,
                                                    backgroundImage: NetworkImage(driverData['photoUrl']),
                                                  )
                                                else
                                                  const CircleAvatar(
                                                    radius: 32,
                                                    child: Icon(Icons.person, size: 32),
                                                  ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(driverData['fullName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                                      if (driverData['email'] != null)
                                                        Text(driverData['email'], style: const TextStyle(color: Colors.grey)),
                                                      if (driverData['phone'] != null)
                                                        Text(driverData['phone'], style: const TextStyle(color: Colors.grey)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                const Icon(Icons.cake, size: 18, color: Colors.grey),
                                                const SizedBox(width: 6),
                                                Text('DOB: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                Text(_formatDateString(driverData['dateOfBirth'])),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.wc, size: 18, color: Colors.grey),
                                                const SizedBox(width: 6),
                                                Text('Gender: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                Text(driverData['gender'] ?? '-'),
                                              ],
                                            ),
                                            if (driverData['race'] != null) ...[
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  const Icon(Icons.flag, size: 18, color: Colors.grey),
                                                  const SizedBox(width: 6),
                                                  Text('Race: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  Text(driverData['race']),
                                                ],
                                              ),
                                            ],
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                                const SizedBox(width: 6),
                                                Text('Joined: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                Text(_formatDateString(driverData['createdAt'])),
                                              ],
                                            ),
                                            if (driverData['bio'] != null && driverData['bio'].toString().isNotEmpty) ...[
                                              const SizedBox(height: 12),
                                              Text(driverData['bio'], style: const TextStyle(fontSize: 16)),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              _infoRow(Icons.location_on, 'From:', startLocation),
                              const SizedBox(height: 8),
                              _infoRow(Icons.flag, 'To:', endLocation),
                              const SizedBox(height: 8),
                              _infoRow(Icons.directions_car, 'Vehicle:', '${vehicle} - ${vehicleModel}'),
                              const SizedBox(height: 8),
                              _infoRow(Icons.people, 'Capacity:', capacity.toString()),
                              const SizedBox(height: 8),
                              _infoRow(Icons.event_seat, 'Remaining Seats:', remainingSeats.toString()),
                              const SizedBox(height: 8),
                              if (departureDateTime != null)
                                _infoRow(Icons.calendar_today, 'Departure:', DateFormat('MMM dd, yyyy - HH:mm').format(departureDateTime)),
                              const SizedBox(height: 8),
                              _infoRow(Icons.attach_money, 'Fare per person:', 'RM ${fare.toStringAsFixed(2)}'),
                              const SizedBox(height: 16),
                              if (widget.mode == RideDetailsMode.offer && !widget.hideApplications) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.people, size: 20, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text('Applications: $applicationsCount', style: const TextStyle(fontSize: 16, color: Colors.blue)),
                                  ],
                                ),
                                const SizedBox(height: 24),
                              ],
                              Row(
                                children: [
                                  if (widget.mode == RideDetailsMode.review) ...[
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          elevation: 0,
                                        ),
                                        child: const Text('Back'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          elevation: 0,
                                        ),
                                        child: const Text('Create Ride', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ] else if (widget.mode == RideDetailsMode.find && !widget.hideJoinButton) ...[
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _isLoadingJoin ? null : handleJoin,
                                        icon: _isLoadingJoin
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Icon(Icons.add),
                                        label: Text(_isLoadingJoin ? 'Joining...' : 'Join Ride'),
                                      ),
                                    ),
                                  ] else if (widget.mode == RideDetailsMode.offer) ...[
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              // Check if there are any applications for this ride
                                              final appsSnapshot = await FirebaseFirestore.instance
                                                  .collection('applications')
                                                  .where('ride_id', isEqualTo: widget.rideId)
                                                  .get();
                                              if (appsSnapshot.docs.isEmpty) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('There are no applications for this ride.')),
                                                );
                                                return;
                                              }
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => RideApplicationsScreen(rideId: widget.rideId),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.people),
                                            label: const Text('View Applications'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              elevation: 0,
                                            ),
                                          ),
                                          if (!widget.hideEditCancel) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    onPressed: nonRejectedApplications == 0
                                                        ? () async {
                                                            // Cancel ride: update status to 'cancel' and updated_at
                                                            await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
                                                              'status': 'cancel',
                                                              'updated_at': FieldValue.serverTimestamp(),
                                                            });
                                                            if (mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                const SnackBar(content: Text('Ride cancelled.')),
                                                              );
                                                              Navigator.pop(context);
                                                            }
                                                          }
                                                        : () {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(content: Text('Cannot cancel: There are active applications for this ride.')),
                                                            );
                                                          },
                                                    icon: const Icon(Icons.cancel),
                                                    label: const Text('Cancel'),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: Colors.red,
                                                      side: const BorderSide(color: Colors.red),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    onPressed: nonRejectedApplications == 0
                                                        ? () {
                                                            final user = context.read<AuthProvider>().user;
                                                            if (user == null) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                const SnackBar(content: Text('User not found. Please log in again.')),
                                                              );
                                                              return;
                                                            }
                                                            // Add rideId to rideData for editing
                                                            final Map<String, dynamic> rideDataWithId = Map<String, dynamic>.from(rideData);
                                                            rideDataWithId['id'] = widget.rideId;
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) => CreateRideScreen(
                                                                  user: user,
                                                                  rideData: rideDataWithId,
                                                                  isEdit: true,
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        : () {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(content: Text('Cannot edit: There are active applications for this ride.')),
                                                            );
                                                          },
                                                    icon: const Icon(Icons.edit),
                                                    label: const Text('Edit'),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: AppColors.primary,
                                                      side: BorderSide(color: AppColors.primary),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }

  void _openGoogleMaps(LatLng destination) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${destination.latitude},${destination.longitude}';
    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        // Fallback to general Google Maps URL
        final fallbackUrl = 'https://www.google.com/maps';
        if (await canLaunch(fallbackUrl)) {
          await launch(fallbackUrl);
        }
      }
    } catch (e) {
      print(e);
    }
  }
} 