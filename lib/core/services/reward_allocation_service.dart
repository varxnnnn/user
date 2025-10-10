import 'package:cloud_firestore/cloud_firestore.dart';

class RewardAllocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Allocates a reward to a user when they complete an activity
  /// GUARANTEES a reward will be allocated - creates fallback if no assigned items available
  /// Returns the allocated reward data or null if allocation fails
  Future<Map<String, dynamic>?> allocateRewardToUser({
    required String activityId,
    required String userId,
    required String sponsorId,
    required String rewardId,
  }) async {
    try {
      // Get the activity data to check reward allocation
      final activityDoc = await _firestore
          .collection('sponsor_activities')
          .doc(activityId)
          .get();

      if (!activityDoc.exists) {
        throw Exception('Activity not found');
      }

      final activityData = activityDoc.data()!;
      final rewardAllocation = activityData['reward_allocation'] as Map<String, dynamic>?;
      
      if (rewardAllocation == null) {
        throw Exception('No reward allocation found for this activity');
      }

      final assignedItemIds = rewardAllocation['assigned_item_ids'] as List<dynamic>? ?? [];
      final remainingQuantity = rewardAllocation['remaining_quantity'] as int? ?? 0;

      String? selectedRewardId;
      int rewardValue = 0;
      String rewardCode = '';

      // Try to find an unused reward from assigned_item_ids first
      if (remainingQuantity > 0 && assignedItemIds.isNotEmpty) {
        for (String itemId in assignedItemIds) {
          // Check if this reward item is available (not assigned to any user)
          final rewardItemDoc = await _firestore
              .collection('sponsor_rewards')
              .doc(sponsorId)
              .collection('items')
              .doc(itemId)
              .get();

          if (rewardItemDoc.exists) {
            final rewardItemData = rewardItemDoc.data()!;
            final assignedTo = rewardItemData['assigned_to'];
            final status = rewardItemData['status'];
            
            // Check if this reward item is available (not assigned to any user)
            if (assignedTo == null && status == 'assigned') {
              selectedRewardId = itemId;
              break;
            }
          }
        }
      }

      // If no assigned item available, create a fallback reward
      if (selectedRewardId == null) {
        print('No assigned items available, creating fallback reward for activity: $activityId');
        
        // Create a fallback reward with default values
        selectedRewardId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
        rewardValue = 50; // Default fallback reward value
        rewardCode = 'FALLBACK-${DateTime.now().millisecondsSinceEpoch}';
        
        // Create the fallback reward item in sponsor_rewards
        await _firestore
            .collection('sponsor_rewards')
            .doc(sponsorId)
            .collection('items')
            .doc(selectedRewardId)
            .set({
          'activity_id': activityId,
          'assigned_at': FieldValue.serverTimestamp(),
          'assigned_to': null,
          'code': rewardCode,
          'created_at': FieldValue.serverTimestamp(),
          'status': 'assigned',
          'value': rewardValue,
        });
      }

      // Get the reward details from sponsor_rewards (if not already set from fallback)
      if (rewardValue == 0) {
        final rewardDoc = await _firestore
            .collection('sponsor_rewards')
            .doc(sponsorId)
            .collection('items')
            .doc(selectedRewardId)
            .get();

        if (!rewardDoc.exists) {
          throw Exception('Reward item not found');
        }

        final rewardData = rewardDoc.data()!;
        rewardValue = rewardData['value'] as int? ?? 50; // Default to 50 if not found
        rewardCode = rewardData['code'] as String? ?? 'REWARD-${DateTime.now().millisecondsSinceEpoch}';
      }

      // Update the reward item to assign it to the user
      await _firestore
          .collection('sponsor_rewards')
          .doc(sponsorId)
          .collection('items')
          .doc(selectedRewardId)
          .update({
        'assigned_to': userId,
        'status': 'issued',
        'issued_at': FieldValue.serverTimestamp(),
      });

      // Create reward assignment record
      final assignmentId = _firestore.collection('reward_assignments').doc().id;
      await _firestore.collection('reward_assignments').doc(assignmentId).set({
        'activity_id': activityId,
        'user_id': userId,
        'sponsor_id': sponsorId,
        'assigned_item_id': selectedRewardId,
        'reward_id': rewardId,
        'value': rewardValue,
        'code': rewardCode,
        'status': 'issued',
        'assigned_at': FieldValue.serverTimestamp(),
        'issued_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      });

      // Update activity's remaining quantity
      await _firestore
          .collection('sponsor_activities')
          .doc(activityId)
          .update({
        'reward_allocation.remaining_quantity': FieldValue.increment(-1),
      });

      // Add reward value to user's wallet/points
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'points': FieldValue.increment(rewardValue),
      });

      // Add to user's earned rewards
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('rewards_earned')
          .doc(activityId)
          .set({
        'activity_id': activityId,
        'reward_assignment_id': assignmentId,
        'reward_value': rewardValue,
        'reward_code': rewardCode,
        'assigned_item_id': selectedRewardId,
        'sponsor_id': sponsorId,
        'status': 'issued',
        'issued_at': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      return {
        'assignment_id': assignmentId,
        'reward_value': rewardValue,
        'reward_code': rewardCode,
        'assigned_item_id': selectedRewardId,
        'status': 'issued',
      };

    } catch (e) {
      print('Error allocating reward: $e');
      return null;
    }
  }

  /// Checks if user has already completed an activity
  Future<bool> hasUserCompletedActivity({
    required String activityId,
    required String userId,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('rewards_earned')
          .doc(activityId)
          .get();

      return doc.exists;
    } catch (e) {
      print('Error checking activity completion: $e');
      return false;
    }
  }

  /// Gets user's earned rewards
  Future<List<Map<String, dynamic>>> getUserEarnedRewards(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('rewards_earned')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'activity_id': data['activity_id'],
          'reward_value': data['reward_value'] ?? 0,
          'reward_code': data['reward_code'] ?? '',
          'assigned_item_id': data['assigned_item_id'],
          'timestamp': data['timestamp'],
        };
      }).toList();
    } catch (e) {
      print('Error fetching user rewards: $e');
      return [];
    }
  }

  /// Gets available rewards for an activity
  Future<Map<String, dynamic>?> getActivityRewardInfo(String activityId) async {
    try {
      final doc = await _firestore
          .collection('sponsor_activities')
          .doc(activityId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final rewardAllocation = data['reward_allocation'] as Map<String, dynamic>?;
      
      if (rewardAllocation == null) return null;

      return {
        'remaining_quantity': rewardAllocation['remaining_quantity'] ?? 0,
        'allocated_quantity': rewardAllocation['allocated_quantity'] ?? 0,
        'assigned_item_ids': rewardAllocation['assigned_item_ids'] ?? [],
        'reward_id': rewardAllocation['reward_id'],
        'sponsor_id': data['sponsor_id'],
      };
    } catch (e) {
      print('Error fetching activity reward info: $e');
      return null;
    }
  }
}
