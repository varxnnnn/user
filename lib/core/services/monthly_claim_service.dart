import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyClaimService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current month ID (format: YYYY-MM)
  String getCurrentMonthId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Check if user has already claimed entry for current month
  Future<bool> hasClaimedThisMonth(String userId) async {
    final monthId = getCurrentMonthId();
    final doc = await _firestore
        .collection('monthly_claims')
        .doc(monthId)
        .collection('participants')
        .doc(userId)
        .get();
    
    return doc.exists;
  }

  /// Claim entry for monthly lucky draw
  Future<bool> claimMonthlyEntry({
    required String userId,
    required String activityId,
    required String activityType,
    required String activityTitle,
  }) async {
    try {
      final monthId = getCurrentMonthId();
      final now = DateTime.now();
      
      // Check if already claimed
      if (await hasClaimedThisMonth(userId)) {
        return false;
      }

      // Get user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};

      // Add to monthly claims
      await _firestore
          .collection('monthly_claims')
          .doc(monthId)
          .collection('participants')
          .doc(userId)
          .set({
        'userId': userId,
        'userName': userData['name'] ?? 'Unknown',
        'userEmail': userData['email'] ?? '',
        'activityId': activityId,
        'activityType': activityType,
        'activityTitle': activityTitle,
        'claimedAt': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, selected, not_selected
        'monthId': monthId,
        'yearMonth': {
          'year': now.year,
          'month': now.month,
        },
      });

      // Create/update monthly claims document
      await _firestore
          .collection('monthly_claims')
          .doc(monthId)
          .set({
        'monthId': monthId,
        'year': now.year,
        'month': now.month,
        'startDate': DateTime(now.year, now.month, 1),
        'endDate': DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        'status': 'active',
        'totalParticipants': FieldValue.increment(1),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Error claiming monthly entry: $e');
      return false;
    }
  }

  /// Get user's monthly claim status
  Future<MonthlyClaimStatus?> getUserMonthlyStatus(String userId) async {
    final monthId = getCurrentMonthId();
    final doc = await _firestore
        .collection('monthly_claims')
        .doc(monthId)
        .collection('participants')
        .doc(userId)
        .get();
    
    if (!doc.exists) {
      return null;
    }

    final data = doc.data()!;
    final status = data['status'] as String? ?? 'pending';
    final rewardData = data['reward'] as Map<String, dynamic>?;

    return MonthlyClaimStatus(
      hasClaimed: true,
      status: status,
      claimedAt: data['claimedAt'] as Timestamp?,
      activityTitle: data['activityTitle'] as String?,
      reward: rewardData,
    );
  }

  /// Check if current month has ended
  bool hasMonthEnded() {
    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return now.isAfter(endOfMonth);
  }

  /// Get all months with claims
  Stream<QuerySnapshot> getAllMonthsClaims() {
    return _firestore
        .collection('monthly_claims')
        .orderBy('year', descending: true)
        .orderBy('month', descending: true)
        .snapshots();
  }

  /// Get participants for a specific month (for admin)
  Stream<QuerySnapshot> getMonthParticipants(String monthId) {
    return _firestore
        .collection('monthly_claims')
        .doc(monthId)
        .collection('participants')
        .snapshots();
  }
}

class MonthlyClaimStatus {
  final bool hasClaimed;
  final String status; // pending, selected, not_selected
  final Timestamp? claimedAt;
  final String? activityTitle;
  final Map<String, dynamic>? reward;

  MonthlyClaimStatus({
    required this.hasClaimed,
    required this.status,
    this.claimedAt,
    this.activityTitle,
    this.reward,
  });

  bool get isPending => status == 'pending';
  bool get isSelected => status == 'selected';
  bool get isNotSelected => status == 'not_selected';
}
