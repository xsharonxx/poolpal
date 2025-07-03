import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/constants.dart';

class RideCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String? rideId;
  final bool showOfferedUser;
  final VoidCallback? onTap;
  final bool isMyOfferedRide;
  final bool hideApplications;
  final Widget? extraInfo;

  const RideCard({
    Key? key,
    required this.data,
    this.rideId,
    this.showOfferedUser = false,
    this.onTap,
    this.isMyOfferedRide = false,
    this.hideApplications = false,
    this.extraInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int capacity = (data['capacity'] as num?)?.toInt() ?? 0;
    final fare = data['fare'] ?? 0;
    final title = data['title'] ?? 'Untitled Ride';
    final createdAt = data['created_at'];
    final startLocation = data['start_location']?['name'] ?? 'Unknown location';
    final endLocation = data['end_location']?['name'] ?? 'Unknown location';
    final departure = data['datetime'];

    Widget remainingSeatsWidget(int remaining) => _buildInfoRow(Icons.event_seat, 'Remaining Seats', remaining.toString());

    Widget applicationsWidget(int count) => Row(
      children: [
        const Icon(Icons.people, size: 16, color: Colors.blue),
        const SizedBox(width: 6),
        Text('Applications: $count', style: const TextStyle(fontSize: 14, color: Colors.blue)),
      ],
    );

    Widget cardContent({required int remaining, int? applicationsCount}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Title and Fare
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isMyOfferedRide) ...[
                          const Icon(Icons.person, size: 20, color: Colors.blue),
                          SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created: ${_formatDateTime(createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
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
          // Ride Details
          _buildInfoRow(Icons.location_on, 'From', startLocation),
          const SizedBox(height: 4),
          _buildInfoRow(Icons.location_on_outlined, 'To', endLocation),
          const SizedBox(height: 4),
          _buildInfoRow(Icons.directions_car, 'Vehicle', '${data['vehicle'] ?? 'Unknown'} - ${data['vehicle_model'] ?? 'Unknown'}'),
          const SizedBox(height: 4),
          _buildInfoRow(Icons.access_time, 'Departure', _formatDateTime(departure)),
          const SizedBox(height: 4),
          _buildInfoRow(Icons.people, 'Capacity', capacity.toString()),
          const SizedBox(height: 4),
          remainingSeatsWidget(remaining),
          if (applicationsCount != null && !hideApplications) ...[
            const SizedBox(height: 4),
            applicationsWidget(applicationsCount),
          ],
          const SizedBox(height: 12),
          if (showOfferedUser)
            _OfferedUserInfo(uid: data['uid']),
          if (showOfferedUser) const SizedBox(height: 12),
          if (extraInfo != null) ...[
            const SizedBox(height: 8),
            extraInfo!,
          ],
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: (rideId != null && !showOfferedUser)
              ? StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('applications')
                      .where('ride_id', isEqualTo: rideId)
                      .where('status', whereIn: ['pending', 'accept'])
                      .snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    int pendingCount = docs.where((doc) => doc['status'] == 'pending').length;
                    int booked = docs.length; // both pending and accept
                    int remaining = capacity - booked;
                    int applicationsCount = pendingCount;
                    return cardContent(remaining: remaining, applicationsCount: applicationsCount);
                  },
                )
              : (rideId != null)
                ? StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('applications')
                        .where('ride_id', isEqualTo: rideId)
                        .where('status', whereIn: ['pending', 'accept'])
                        .snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      int booked = docs.length; // both pending and accept
                      int remaining = capacity - booked;
                      return cardContent(remaining: remaining);
                    },
                  )
                : cardContent(remaining: capacity - ((data['passengers'] as List?)?.length ?? 0)),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: Colors.grey[600]),
        ),
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

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';
    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else {
        return 'Invalid time';
      }
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid time';
    }
  }
}

class _OfferedUserInfo extends StatelessWidget {
  final String? uid;
  const _OfferedUserInfo({Key? key, required this.uid}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasData && userSnapshot.data != null) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          final userName = userData?['fullName'] ?? 'Unknown User';
          final userProfileImage = userData?['photoUrl'];
          return Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: userProfileImage != null ? NetworkImage(userProfileImage) : null,
                child: userProfileImage == null
                    ? Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
                backgroundColor: userProfileImage == null ? AppColors.primary : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offered by $userName',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          );
        } else {
          return const Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
              SizedBox(width: 8),
              Text(
                'Offered by Unknown User',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ],
          );
        }
      },
    );
  }
} 