import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Ensures all activities have proper reward allocation structure
  /// This should be run once to migrate existing activities
  Future<void> migrateActivitiesForRewardAllocation() async {
    try {
      print('Starting activity migration for reward allocation...');

      // Get all activities that don't have reward_allocation
      final activitiesSnapshot = await _firestore
          .collection('sponsor_activities')
          .where('reward_allocation', isNull: true)
          .get();

      print('Found ${activitiesSnapshot.docs.length} activities without reward allocation');

      for (var doc in activitiesSnapshot.docs) {
        final activityData = doc.data();
        final activityId = doc.id;
        final sponsorId = activityData['sponsor_id'] as String?;

        if (sponsorId == null) {
          print('Skipping activity $activityId - no sponsor_id');
          continue;
        }

        // Create default reward allocation structure
        final rewardAllocation = {
          'allocated_quantity': 100, // Default quantity
          'assigned_at': FieldValue.serverTimestamp(),
          'assigned_item_ids': [], // Will be populated with fallback rewards
          'remaining_quantity': 100,
          'reward_id': 'default_reward_${DateTime.now().millisecondsSinceEpoch}',
        };

        // Create default reward items
        final assignedItemIds = <String>[];
        for (int i = 0; i < 10; i++) { // Create 10 default reward items
          final itemId = 'default_item_${activityId}_${i}_${DateTime.now().millisecondsSinceEpoch}';
          assignedItemIds.add(itemId);

          // Create the reward item
          await _firestore
              .collection('sponsor_rewards')
              .doc(sponsorId)
              .collection('items')
              .doc(itemId)
              .set({
            'activity_id': activityId,
            'assigned_at': FieldValue.serverTimestamp(),
            'assigned_to': null,
            'code': 'REWARD-${DateTime.now().millisecondsSinceEpoch}-$i',
            'created_at': FieldValue.serverTimestamp(),
            'status': 'assigned',
            'value': 50, // Default reward value
          });
        }

        // Update reward allocation with assigned item IDs
        rewardAllocation['assigned_item_ids'] = assignedItemIds;

        // Update the activity with reward allocation
        await _firestore
            .collection('sponsor_activities')
            .doc(activityId)
            .update({
          'reward_allocation': rewardAllocation,
        });

        print('Updated activity $activityId with reward allocation');
      }

      print('Activity migration completed successfully!');
    } catch (e) {
      print('Error during activity migration: $e');
      rethrow;
    }
  }

  /// Creates a default reward allocation for a new activity
  Future<void> createDefaultRewardAllocation({
    required String activityId,
    required String sponsorId,
    int defaultQuantity = 100,
    int defaultRewardValue = 50,
  }) async {
    try {
      // Create default reward items
      final assignedItemIds = <String>[];
      for (int i = 0; i < defaultQuantity; i++) {
        final itemId = 'item_${activityId}_${i}_${DateTime.now().millisecondsSinceEpoch}';
        assignedItemIds.add(itemId);

        // Create the reward item
        await _firestore
            .collection('sponsor_rewards')
            .doc(sponsorId)
            .collection('items')
            .doc(itemId)
            .set({
          'activity_id': activityId,
          'assigned_at': FieldValue.serverTimestamp(),
          'assigned_to': null,
          'code': 'REWARD-${DateTime.now().millisecondsSinceEpoch}-$i',
          'created_at': FieldValue.serverTimestamp(),
          'status': 'assigned',
          'value': defaultRewardValue,
        });
      }

      // Create reward allocation structure
      final rewardAllocation = {
        'allocated_quantity': defaultQuantity,
        'assigned_at': FieldValue.serverTimestamp(),
        'assigned_item_ids': assignedItemIds,
        'remaining_quantity': defaultQuantity,
        'reward_id': 'reward_${activityId}_${DateTime.now().millisecondsSinceEpoch}',
      };

      // Update the activity with reward allocation
      await _firestore
          .collection('sponsor_activities')
          .doc(activityId)
          .update({
        'reward_allocation': rewardAllocation,
      });

      print('Created default reward allocation for activity $activityId');
    } catch (e) {
      print('Error creating default reward allocation: $e');
      rethrow;
    }
  }

  /// Validates that all activities have proper reward allocation
  Future<Map<String, dynamic>> validateRewardAllocation() async {
    try {
      final activitiesSnapshot = await _firestore
          .collection('sponsor_activities')
          .get();

      int totalActivities = activitiesSnapshot.docs.length;
      int activitiesWithRewardAllocation = 0;
      int activitiesWithoutRewardAllocation = 0;
      List<String> problematicActivities = [];

      for (var doc in activitiesSnapshot.docs) {
        final activityData = doc.data();
        final rewardAllocation = activityData['reward_allocation'] as Map<String, dynamic>?;

        if (rewardAllocation == null) {
          activitiesWithoutRewardAllocation++;
          problematicActivities.add(doc.id);
        } else {
          final assignedItemIds = rewardAllocation['assigned_item_ids'] as List<dynamic>? ?? [];
          final remainingQuantity = rewardAllocation['remaining_quantity'] as int? ?? 0;

          if (assignedItemIds.isEmpty || remainingQuantity <= 0) {
            activitiesWithoutRewardAllocation++;
            problematicActivities.add(doc.id);
          } else {
            activitiesWithRewardAllocation++;
          }
        }
      }

      return {
        'total_activities': totalActivities,
        'activities_with_reward_allocation': activitiesWithRewardAllocation,
        'activities_without_reward_allocation': activitiesWithoutRewardAllocation,
        'problematic_activities': problematicActivities,
        'is_valid': activitiesWithoutRewardAllocation == 0,
      };
    } catch (e) {
      print('Error validating reward allocation: $e');
      return {
        'error': e.toString(),
        'is_valid': false,
      };
    }
  }
}

