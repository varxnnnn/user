import 'package:cloud_firestore/cloud_firestore.dart';

class RewardAllocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Allocates a reward to a user when they complete an activity.
  /// Guarantees allocation for coins/points via fallback; returns null for non-fallbackable types if no items available.
  Future<Map<String, dynamic>?> allocateRewardToUser({
    required String activityId,
    required String userId,
    required String sponsorId,
    required String rewardId,
  }) async {
    try {
      // 1️⃣ Fetch activity
      final activityDoc = await _firestore
          .collection('sponsor_activities')
          .doc(activityId)
          .get();
      if (!activityDoc.exists) throw Exception('Activity not found');
      final activityData = activityDoc.data()!;
      final rewardAllocation =
          activityData['reward_allocation'] as Map<String, dynamic>?;
      if (rewardAllocation == null) {
        throw Exception('No reward allocation found for this activity');
      }

      // 2️⃣ Fetch reward
      final rewardDoc = await _firestore
          .collection('sponsor_rewards')
          .doc(rewardId)
          .get();
      if (!rewardDoc.exists) throw Exception('Reward not found');
      final rewardData = rewardDoc.data()!;
      final rewardType = (rewardData['type'] as String?)?.toLowerCase() ?? 'points';
      final rewardTitle = rewardData['title'] as String? ?? 'Reward';
      final rewardDescription = rewardData['description'] as String? ?? '';

      final assignedItemIds =
          List<String>.from(rewardAllocation['assigned_item_ids'] ?? []);
      final remainingQuantity = rewardAllocation['remaining_quantity'] as int? ?? 0;

      String? selectedItemId;
      int rewardValue = 0;
      String rewardCode = '';

      // 3️⃣ Try to find an available assigned item
      if (remainingQuantity > 0 && assignedItemIds.isNotEmpty) {
        for (final itemId in assignedItemIds) {
          final itemDoc = await _firestore
              .collection('sponsor_rewards')
              .doc(rewardId)
              .collection('items')
              .doc(itemId)
              .get();

          if (itemDoc.exists) {
            final itemData = itemDoc.data()!;
            if (itemData['assigned_to'] == null &&
                (itemData['status'] == null || itemData['status'] == 'assigned')) {
              selectedItemId = itemId;
              // Extract value: support both direct 'value' and nested 'metadata.coins.amount'
              final metadata = itemData['metadata'] as Map<String, dynamic>? ?? {};
              final coins = metadata['coins'] as Map<String, dynamic>? ?? {};
              rewardValue = coins['amount'] as int? ??
                  itemData['value'] as int? ??
                  0;
              rewardCode = itemData['code'] as String? ??
                  'REWARD-${DateTime.now().millisecondsSinceEpoch}';
              break;
            }
          }
        }
      }

      // 4️⃣ Fallback for coins/points only
      if (selectedItemId == null) {
        print('⚠️ No assigned items available for activity $activityId');
        if (['coins', 'points'].contains(rewardType)) {
          selectedItemId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
          rewardValue = rewardData['value'] as int? ?? 0;
          rewardCode = 'FALLBACK-${DateTime.now().millisecondsSinceEpoch}';

          // Create fallback item under the correct reward
          await _firestore
              .collection('sponsor_rewards')
              .doc(rewardId)
              .collection('items')
              .doc(selectedItemId)
              .set({
            'activity_id': activityId,
            'assigned_at': FieldValue.serverTimestamp(),
            'assigned_to': null,
            'code': rewardCode,
            'created_at': FieldValue.serverTimestamp(),
            'status': 'assigned',
            'value': rewardValue, // Optional: also store directly for simplicity
            'metadata': {
              'coins': {'amount': rewardValue}
            },
          });
        } else {
          // Non-fallbackable types (voucher/product) → fail gracefully
          return null;
        }
      }

      // 5️⃣ Assign item to user
      await _firestore
          .collection('sponsor_rewards')
          .doc(rewardId)
          .collection('items')
          .doc(selectedItemId!)
          .update({
        'assigned_to': userId,
        'status': 'issued',
        'issued_at': FieldValue.serverTimestamp(),
      });

      // 6️⃣ Create assignment record
      final assignmentId = _firestore.collection('reward_assignments').doc().id;
      await _firestore.collection('reward_assignments').doc(assignmentId).set({
        'activity_id': activityId,
        'user_id': userId,
        'sponsor_id': sponsorId,
        'assigned_item_id': selectedItemId,
        'reward_id': rewardId,
        'value': rewardValue,
        'code': rewardCode,
        'status': 'issued',
        'assigned_at': FieldValue.serverTimestamp(),
        'issued_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      });

      // 7️⃣ Decrement remaining quantity
      await _firestore.collection('sponsor_activities').doc(activityId).update({
        'reward_allocation.remaining_quantity': FieldValue.increment(-1),
      });

      // 8️⃣ Apply reward logic
      if (['coins', 'points'].contains(rewardType)) {
        if (rewardValue > 0) {
          await _firestore.collection('users').doc(userId).update({
            'points': FieldValue.increment(rewardValue),
          });
          print('✅ Added $rewardValue $rewardType to user $userId');
        }
      } else if (['voucher', 'product', 'products'].contains(rewardType)) {
        await _firestore.collection('redemptions').add({
          'user_id': userId,
          'reward_id': rewardId,
          'status': 'pending',
          'delivery_info': {'address': '', 'contact': ''},
          'redeemed_at': FieldValue.serverTimestamp(),
        });
        print('🎁 Created redemption for $rewardType');
      }

      // 9️⃣ Record in user's earned rewards
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
        'assigned_item_id': selectedItemId,
        'sponsor_id': sponsorId,
        'reward_type': rewardType,
        'reward_title': rewardTitle,
        'reward_description': rewardDescription,
        'status': 'issued',
        'issued_at': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      return {
        'assignment_id': assignmentId,
        'reward_value': rewardValue,
        'reward_code': rewardCode,
        'assigned_item_id': selectedItemId,
        'reward_type': rewardType,
        'reward_title': rewardTitle,
        'status': 'issued',
      };

    } catch (e, stack) {
      print('❌ Error allocating reward: $e\n$stack');
      return null;
    }
  }

  // --- Remaining helper methods unchanged ---
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