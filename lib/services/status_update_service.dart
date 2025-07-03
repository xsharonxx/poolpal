import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class StatusUpdateService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static Timer? _periodicTimer;

  /// Update all statuses on app launch
  static Future<void> updateAllStatuses() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = Timestamp.now();
    
    // Update rides offered by user
    await _updateOfferedRides(user.uid, now);
    
    // Update rides user joined
    await _updateJoinedRides(user.uid, now);
    
    // Update user's applications
    await _updateUserApplications(user.uid, now);
  }

  /// Update rides offered by the user
  static Future<void> _updateOfferedRides(String userId, Timestamp now) async {
    final ridesQuery = await _firestore
        .collection('rides')
        .where('uid', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .get();

    final batch = _firestore.batch();
    bool hasUpdates = false;
    
    for (final doc in ridesQuery.docs) {
      final data = doc.data();
      final departureTime = data['datetime'] as Timestamp?;
      
      if (departureTime != null && departureTime.toDate().isBefore(now.toDate())) {
        batch.update(doc.reference, {
          'status': 'passed',
          'updated_at': now,
        });
        hasUpdates = true;
      }
    }
    
    if (hasUpdates) {
      await batch.commit();
    }
  }

  /// Update rides the user joined
  static Future<void> _updateJoinedRides(String userId, Timestamp now) async {
    // Get accepted applications by user
    final applicationsQuery = await _firestore
        .collection('applications')
        .where('uid', isEqualTo: userId)
        .where('status', isEqualTo: 'accept')
        .get();

    final batch = _firestore.batch();
    bool hasUpdates = false;
    
    for (final appDoc in applicationsQuery.docs) {
      final data = appDoc.data() as Map<String, dynamic>;
      final rideId = data['ride_id'] as String;
      
      // Get the ride document
      final rideDoc = await _firestore.collection('rides').doc(rideId).get();
      if (rideDoc.exists) {
        final rideData = rideDoc.data()!;
        final departureTime = rideData['datetime'] as Timestamp?;
        
        if (departureTime != null && departureTime.toDate().isBefore(now.toDate())) {
          // Update the ride status
          batch.update(rideDoc.reference, {
            'status': 'passed',
            'updated_at': now,
          });
          hasUpdates = true;
        }
      }
    }
    
    if (hasUpdates) {
      await batch.commit();
    }
  }

  /// Update user's applications that haven't been responded to
  static Future<void> _updateUserApplications(String userId, Timestamp now) async {
    final applicationsQuery = await _firestore
        .collection('applications')
        .where('uid', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    final batch = _firestore.batch();
    bool hasUpdates = false;
    
    for (final appDoc in applicationsQuery.docs) {
      final data = appDoc.data() as Map<String, dynamic>;
      final rideId = data['ride_id'] as String;
      
      // Get the ride document
      final rideDoc = await _firestore.collection('rides').doc(rideId).get();
      if (rideDoc.exists) {
        final rideData = rideDoc.data()!;
        final departureTime = rideData['datetime'] as Timestamp?;
        
        if (departureTime != null && departureTime.toDate().isBefore(now.toDate())) {
          // Update application status to reject
          batch.update(appDoc.reference, {
            'status': 'reject',
            'updated_at': now,
          });
          hasUpdates = true;
        }
      }
    }
    
    if (hasUpdates) {
      await batch.commit();
    }
  }

  /// Set up real-time listeners for ongoing updates
  static void setupRealTimeListeners() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Cancel existing timer if any
    _periodicTimer?.cancel();

    // Set up periodic timer to check every 5 minutes
    _periodicTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      updateAllStatuses();
    });

    // Listen for rides offered by user
    _firestore
        .collection('rides')
        .where('uid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      _handleRideUpdates(snapshot.docs, user.uid);
    });

    // Listen for user's applications
    _firestore
        .collection('applications')
        .where('uid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      _handleApplicationUpdates(snapshot.docs, user.uid);
    });
  }

  /// Handle real-time ride updates
  static Future<void> _handleRideUpdates(List<QueryDocumentSnapshot> rides, String userId) async {
    final now = Timestamp.now();
    final batch = _firestore.batch();
    bool hasUpdates = false;
    
    for (final doc in rides) {
      final data = doc.data() as Map<String, dynamic>;
      final departureTime = data['datetime'] as Timestamp?;
      
      if (departureTime != null && departureTime.toDate().isBefore(now.toDate())) {
        batch.update(doc.reference, {
          'status': 'passed',
          'updated_at': now,
        });
        hasUpdates = true;
      }
    }
    
    if (hasUpdates) {
      await batch.commit();
    }
  }

  /// Handle real-time application updates
  static Future<void> _handleApplicationUpdates(List<QueryDocumentSnapshot> applications, String userId) async {
    final now = Timestamp.now();
    final batch = _firestore.batch();
    bool hasUpdates = false;
    
    for (final appDoc in applications) {
      final data = appDoc.data() as Map<String, dynamic>;
      final rideId = data['ride_id'] as String;
      
      // Get the ride document
      final rideDoc = await _firestore.collection('rides').doc(rideId).get();
      if (rideDoc.exists) {
        final rideData = rideDoc.data()!;
        final departureTime = rideData['datetime'] as Timestamp?;
        
        if (departureTime != null && departureTime.toDate().isBefore(now.toDate())) {
          batch.update(appDoc.reference, {
            'status': 'reject',
            'updated_at': now,
          });
          hasUpdates = true;
        }
      }
    }
    
    if (hasUpdates) {
      await batch.commit();
    }
  }

  /// Clean up listeners and timers
  static void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }
} 