import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RideApplicationsScreen extends StatefulWidget {
  final String rideId;
  const RideApplicationsScreen({Key? key, required this.rideId}) : super(key: key);

  @override
  State<RideApplicationsScreen> createState() => _RideApplicationsScreenState();
}

class _RideApplicationsScreenState extends State<RideApplicationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _compareTimestamps(Timestamp? a, Timestamp? b, {bool ascending = true}) {
    if (a == null && b == null) return 0;
    if (a == null) return ascending ? -1 : 1;
    if (b == null) return ascending ? 1 : -1;
    return ascending ? a.compareTo(b) : b.compareTo(a);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Applications'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Passenger'),
            Tab(text: 'Reject'),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('applications')
              .where('ride_id', isEqualTo: widget.rideId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('There are no applications for this ride.'));
            }
            // Split applications by status
            final pending = docs.where((d) => d['status'] == 'pending').toList()
              ..sort((a, b) => _compareTimestamps(a['created_at'] as Timestamp?, b['created_at'] as Timestamp?, ascending: true));
            final accepted = docs.where((d) => d['status'] == 'accept').toList()
              ..sort((a, b) => _compareTimestamps(b['updated_at'] as Timestamp?, a['updated_at'] as Timestamp?, ascending: true));
            final rejected = docs.where((d) => d['status'] == 'reject').toList()
              ..sort((a, b) => _compareTimestamps(b['updated_at'] as Timestamp?, a['updated_at'] as Timestamp?, ascending: true));

            return TabBarView(
              controller: _tabController,
              children: [
                _ApplicationsList(
                  applications: pending,
                  showActions: true,
                  onAction: _handleAction,
                ),
                _ApplicationsList(
                  applications: accepted,
                  showActions: false,
                ),
                _ApplicationsList(
                  applications: rejected,
                  showActions: false,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleAction(DocumentSnapshot appDoc, String action) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await FirebaseFirestore.instance
          .collection('applications')
          .doc(appDoc.id)
          .update({
        'status': action,
        'updated_at': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Application ${action == 'accept' ? 'accepted' : 'rejected'}')),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class _ApplicationsList extends StatelessWidget {
  final List<DocumentSnapshot> applications;
  final bool showActions;
  final Future<void> Function(DocumentSnapshot, String)? onAction;

  const _ApplicationsList({
    Key? key,
    required this.applications,
    this.showActions = false,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (applications.isEmpty) {
      return const Center(child: Text('No applications in this tab.'));
    }
    return ListView.builder(
      itemCount: applications.length,
      itemBuilder: (context, index) {
        final app = applications[index];
        final userId = app['uid'] as String?;
        return FutureBuilder<DocumentSnapshot>(
          future: userId != null
              ? FirebaseFirestore.instance.collection('users').doc(userId).get()
              : Future.value(null),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final user = userSnap.data?.data() as Map<String, dynamic>?;
            return _ApplicationCard(
              user: user,
              application: app,
              showActions: showActions,
              onAction: onAction,
            );
          },
        );
      },
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic>? user;
  final DocumentSnapshot application;
  final bool showActions;
  final Future<void> Function(DocumentSnapshot, String)? onAction;

  const _ApplicationCard({
    Key? key,
    required this.user,
    required this.application,
    this.showActions = false,
    this.onAction,
  }) : super(key: key);

  String _formatDateString(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMMM d, y').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = application.data() as Map<String, dynamic>;
    final createdAtStr = user?['createdAt'] as String?;
    final dobStr = user?['dateOfBirth'] as String?;
    final createdAt = _formatDateString(createdAtStr);
    final dob = _formatDateString(dobStr);
    final updatedAt = data.containsKey('updated_at') && data['updated_at'] != null
        ? (data['updated_at'] as Timestamp?)?.toDate()
        : null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: user?['photoUrl'] != null
                      ? NetworkImage(user!['photoUrl'])
                      : null,
                  child: user?['photoUrl'] == null
                      ? const Icon(Icons.person, size: 32)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    user?['fullName'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('Email', user?['email']),
            _infoRow('Phone', user?['phone']),
            _infoRow('DOB', dob),
            _infoRow('Gender', user?['gender']),
            _infoRow('Race', user?['race']),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Created At:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 6),
                Text(_formatDate(application['created_at'], withTime: true)),
              ],
            ),
            if (showActions) const SizedBox(height: 12),
            if (data['status'] != 'pending' && updatedAt != null)
              Row(
                children: [
                  const Text('Updated At:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(width: 6),
                  Text(_formatDate(updatedAt, withTime: true)),
                ],
              ),
            if (showActions)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAction != null
                          ? () => onAction!(application, 'reject')
                          : null,
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAction != null
                          ? () => onAction!(application, 'accept')
                          : null,
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value?.toString() ?? '-'),
          ),
        ],
      ),
    );
  }
}

String _formatDate(dynamic date, {bool withTime = false}) {
  if (date == null) return '-';
  final dt = date is Timestamp ? date.toDate() : date as DateTime?;
  if (dt == null) return '-';
  return withTime
      ? DateFormat('yyyy-MM-dd HH:mm').format(dt)
      : DateFormat('yyyy-MM-dd').format(dt);
} 