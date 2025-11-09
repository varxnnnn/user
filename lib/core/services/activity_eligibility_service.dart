import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityEligibilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if user can participate in an activity
  Future<ActivityEligibilityResult> canUserParticipate({
    required String activityId,
    required String userId,
  }) async {
    try {
      // Get activity data
      final activityDoc = await _firestore
          .collection('sponsor_activities')
          .doc(activityId)
          .get();

      if (!activityDoc.exists) {
        return ActivityEligibilityResult(
          canParticipate: false,
          reason: 'Activity not found',
        );
      }

      final activityData = activityDoc.data()!;
      final status = activityData['status'] as String?;
      final endDate = activityData['end_date'] as Timestamp?;
      final rewardDistributionType = activityData['reward_distribution_type'] as String? ?? 'first_come_first_serve';
      final rewardAllocation = activityData['reward_allocation'] as Map<String, dynamic>?;

      // Check if activity is active
      if (status != 'active') {
        return ActivityEligibilityResult(
          canParticipate: false,
          reason: 'Activity is not active',
        );
      }

      // Check if activity has ended
      if (endDate != null && DateTime.now().isAfter(endDate.toDate())) {
        return ActivityEligibilityResult(
          canParticipate: false,
          reason: 'Activity has ended',
        );
      }

      // Check if user has already participated
      final hasParticipated = await _hasUserParticipated(activityId, userId);
      if (hasParticipated) {
        return ActivityEligibilityResult(
          canParticipate: false,
          reason: 'You have already participated in this activity',
        );
      }

      // For first come first serve - check remaining rewards
      if (rewardDistributionType == 'first_come_first_serve') {
        if (rewardAllocation == null) {
          return ActivityEligibilityResult(
            canParticipate: false,
            reason: 'No rewards allocated for this activity',
          );
        }

        final remainingQuantity = rewardAllocation['remaining_quantity'] as int? ?? 0;
        
        // Check if activity is marked as completed (rewards exhausted)
        if (status == 'completed' || remainingQuantity <= 0) {
          return ActivityEligibilityResult(
            canParticipate: false,
            reason: 'All rewards have been claimed. Activity will remain visible until end date.',
            isRewardsCompleted: true,
          );
        }
      }

      // For lucky draw - users can participate until end date regardless of reward quantity
      // No limit on number of participants for lucky draw
      return ActivityEligibilityResult(
        canParticipate: true,
        reason: 'Eligible to participate',
      );
    } catch (e) {
      return ActivityEligibilityResult(
        canParticipate: false,
        reason: 'Error checking eligibility: $e',
      );
    }
  }

  /// Check if user has already participated
  Future<bool> _hasUserParticipated(String activityId, String userId) async {
    final participantDoc = await _firestore
        .collection('activity_participants')
        .doc('${activityId}_$userId')
        .get();
    
    return participantDoc.exists;
  }

  /// Get activity status info
  Future<ActivityStatusInfo> getActivityStatus(String activityId) async {
    try {
      final activityDoc = await _firestore
          .collection('sponsor_activities')
          .doc(activityId)
          .get();

      if (!activityDoc.exists) {
        return ActivityStatusInfo(
          statusText: 'Not Found',
          statusColor: 'grey',
        );
      }

      final activityData = activityDoc.data()!;
      final status = activityData['status'] as String?;
      final endDate = activityData['end_date'] as Timestamp?;
      final rewardDistributionType = activityData['reward_distribution_type'] as String? ?? 'first_come_first_serve';
      final rewardAllocation = activityData['reward_allocation'] as Map<String, dynamic>?;

      // Check if ended
      if (endDate != null && DateTime.now().isAfter(endDate.toDate())) {
        return ActivityStatusInfo(
          statusText: 'Ended',
          statusColor: 'grey',
        );
      }

      // Check if inactive
      if (status != 'active') {
        return ActivityStatusInfo(
          statusText: 'Inactive',
          statusColor: 'grey',
        );
      }

      // For first come first serve - check rewards
      if (rewardDistributionType == 'first_come_first_serve') {
        final remainingQuantity = rewardAllocation?['remaining_quantity'] as int? ?? 0;
        
        if (remainingQuantity <= 0) {
          return ActivityStatusInfo(
            statusText: 'Rewards Completed',
            statusColor: 'orange',
          );
        }

        return ActivityStatusInfo(
          statusText: 'Active - $remainingQuantity left',
          statusColor: 'green',
        );
      }

      // For lucky draw
      return ActivityStatusInfo(
        statusText: 'Active - Lucky Draw',
        statusColor: 'purple',
      );
    } catch (e) {
      return ActivityStatusInfo(
        statusText: 'Error',
        statusColor: 'red',
      );
    }
  }
}

class ActivityEligibilityResult {
  final bool canParticipate;
  final String reason;
  final bool isRewardsCompleted;

  ActivityEligibilityResult({
    required this.canParticipate,
    required this.reason,
    this.isRewardsCompleted = false,
  });
}

class ActivityStatusInfo {
  final String statusText;
  final String statusColor; // green, orange, purple, grey, red

  ActivityStatusInfo({
    required this.statusText,
    required this.statusColor,
  });
}
