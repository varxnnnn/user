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
      print('\n🔵 Starting reward allocation...');
      print('Activity: $activityId, User: $userId, Reward: $rewardId');
      
      // 1️⃣ Fetch activity
      final activityDoc = await _firestore
          .collection('sponsor_activities')
          .doc(activityId)
          .get();
      if (!activityDoc.exists) {
        print('❌ Activity not found');
        throw Exception('Activity not found');
      }
      final activityData = activityDoc.data()!;
      final rewardAllocation =
          activityData['reward_allocation'] as Map<String, dynamic>?;
      if (rewardAllocation == null) {
        print('❌ No reward allocation found');
        throw Exception('No reward allocation found for this activity');
      }

      // 2️⃣ Fetch reward
      final rewardDoc = await _firestore
          .collection('sponsor_rewards')
          .doc(rewardId)
          .get();
      if (!rewardDoc.exists) {
        print('❌ Reward not found');
        throw Exception('Reward not found');
      }
      final rewardData = rewardDoc.data()!;
      final rewardType = (rewardData['type'] as String?)?.toLowerCase() ?? 'points';
      final rewardTitle = rewardData['title'] as String? ?? 'Reward';
      final rewardDescription = rewardData['description'] as String? ?? '';

      print('🎯 Reward type: $rewardType');
      print('🎯 Reward title: $rewardTitle');

      final assignedItemIds =
          List<String>.from(rewardAllocation['assigned_item_ids'] ?? []);
      final remainingQuantity = rewardAllocation['remaining_quantity'] as int? ?? 0;
      
      print('📦 Assigned items count: ${assignedItemIds.length}');
      print('📦 Remaining quantity: $remainingQuantity');

      String? selectedItemId;
      int rewardValue = 0;
      String rewardCode = '';

      // 3️⃣ Try to find an available assigned item
      if (assignedItemIds.isNotEmpty) {
        print('🔍 Searching through ${assignedItemIds.length} assigned items...');
        for (final itemId in assignedItemIds) {
          final itemDoc = await _firestore
              .collection('sponsor_rewards')
              .doc(rewardId)
              .collection('items')
              .doc(itemId)
              .get();

          if (itemDoc.exists) {
            final itemData = itemDoc.data()!;
            final assignedTo = itemData['assigned_to'];
            final status = itemData['status'];
            print('  Item $itemId: assigned_to=$assignedTo, status=$status');
            
            if (assignedTo == null && (status == null || status == 'assigned')) {
              selectedItemId = itemId;
              // Extract value: support both direct 'value' and nested 'metadata.coins.amount'
              final metadata = itemData['metadata'] as Map<String, dynamic>? ?? {};
              final coins = metadata['coins'] as Map<String, dynamic>? ?? {};
              rewardValue = coins['amount'] as int? ??
                  itemData['value'] as int? ??
                  0;
              rewardCode = itemData['code'] as String? ??
                  'REWARD-${DateTime.now().millisecondsSinceEpoch}';
              print('✅ Found available item: $selectedItemId, value: $rewardValue, code: $rewardCode');
              break;
            }
          } else {
            print('  ⚠️ Item $itemId does not exist');
          }
        }
      } else {
        print('⚠️ No assigned items in the list');
      }

      // 4️⃣ Fallback for coins/points only
      if (selectedItemId == null) {
        print('⚠️ No assigned items available for activity $activityId');
        if (['coins', 'points'].contains(rewardType)) {
          print('💡 Creating fallback item for $rewardType');
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
          print('✅ Fallback item created: $selectedItemId');
        } else {
          // Non-fallbackable types (product) → fail gracefully
          print('❌ Non-fallbackable reward type: $rewardType - cannot create fallback');
          return null;
        }
      }

      // 5️⃣ Assign item to user
      print('🔒 Assigning item $selectedItemId to user $userId...');
      await _firestore
          .collection('sponsor_rewards')
          .doc(rewardId)
          .collection('items')
          .doc(selectedItemId)
          .update({
        'assigned_to': userId,
        'status': 'issued',
        'issued_at': FieldValue.serverTimestamp(),
      });
      print('✅ Item assigned to user');

      // 6️⃣ Create assignment record
      final assignmentId = _firestore.collection('reward_assignments').doc().id;
      print('📝 Creating assignment record: $assignmentId');
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
      print('✅ Assignment record created');

      // 7️⃣ Decrement remaining quantity and check if activity should be auto-ended
      final activityUpdateData = <String, dynamic>{
        'reward_allocation.remaining_quantity': FieldValue.increment(-1),
      };
      
      // Check if this is first come first serve and if remaining quantity will reach 0
      final rewardDistributionType = activityData['reward_distribution_type'] as String? ?? 'first_come_first_serve';
      final currentRemaining = remainingQuantity;
      
      print('🔄 Updating activity: distribution=$rewardDistributionType, remaining=$currentRemaining');
      
      if (rewardDistributionType == 'first_come_first_serve' && currentRemaining <= 1) {
        // Auto-end the activity when rewards are exhausted
        activityUpdateData['status'] = 'completed';
        activityUpdateData['rewards_completed_at'] = FieldValue.serverTimestamp();
        print('✅ Auto-ending activity $activityId - all rewards claimed');
      }
      
      await _firestore.collection('sponsor_activities').doc(activityId).update(activityUpdateData);
      print('✅ Activity updated');

      // 8️⃣ Apply reward logic
      print('🎁 Applying reward logic for type: $rewardType');
      if (['coins', 'points'].contains(rewardType)) {
        if (rewardValue > 0) {
          await _firestore.collection('users').doc(userId).update({
            'points': FieldValue.increment(rewardValue),
          });
          print('✅ Added $rewardValue $rewardType to user $userId');
        }
      } else if (['product'].contains(rewardType)) {
        await _firestore.collection('redemptions').add({
          'user_id': userId,
          'reward_id': rewardId,
          'status': 'pending',
          'delivery_info': {'address': '', 'contact': ''},
          'redeemed_at': FieldValue.serverTimestamp(),
        });
        print('🎁 Created redemption for $rewardType');
      }

      // 9️⃣ Record in user's earned rewards with status 'issued' (user needs to claim)
      print('💾 Recording in user rewards_earned...');
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
        'reward_id': rewardId,
        'reward_type': rewardType,
        'reward_title': rewardTitle,
        'reward_description': rewardDescription,
        'status': 'issued', // User needs to claim this reward
        'issued_at': FieldValue.serverTimestamp(),
        'claimed_at': null,
        'timestamp': FieldValue.serverTimestamp(),
        'is_lucky_draw_winner': true,
      });
      print('✅ User rewards_earned record created');

      print('✅✅✅ Reward allocation completed successfully!\n');
      return {
        'assignment_id': assignmentId,
        'reward_value': rewardValue,
        'reward_code': rewardCode,
        'assigned_item_id': selectedItemId,
        'reward_type': rewardType,
        'reward_title': rewardTitle,
        'reward_description': rewardDescription,
        'status': 'issued',
      };

    } catch (e, stack) {
      print('❌ Error allocating reward: $e\n$stack');
      return null;
    }
  }
}

