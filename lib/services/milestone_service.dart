import 'package:cloud_firestore/cloud_firestore.dart';

class MilestoneService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check and update milestones when an activity is completed
  Future<void> checkMilestones({
    required String sponsorId,
    required String activityId,
    required String userId,
  }) async {
    try {
      // Get current month's milestones
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      final milestonesQuery = await _firestore
          .collection('sponsor_milestones')
          .where('sponsor_id', isEqualTo: sponsorId)
          .where('month', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('month', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .where('status', isEqualTo: 'active')
          .get();

      for (var milestoneDoc in milestonesQuery.docs) {
        final milestone = milestoneDoc.data();
        final currentCompletions = milestone['current_completions'] as int;
        final target = milestone['target'] as int;

        // Check if milestone already achieved for this activity
        final achievementQuery = await _firestore
            .collection('milestone_achievements')
            .where('milestone_id', isEqualTo: milestoneDoc.id)
            .where('activity_id', isEqualTo: activityId)
            .where('user_id', isEqualTo: userId)
            .get();

        if (achievementQuery.docs.isEmpty && currentCompletions < target) {
          // Update milestone progress
          await milestoneDoc.reference.update({
            'current_completions': FieldValue.increment(1),
          });

          // Record achievement
          await _firestore.collection('milestone_achievements').add({
            'milestone_id': milestoneDoc.id,
            'activity_id': activityId,
            'user_id': userId,
            'sponsor_id': sponsorId,
            'achieved_at': FieldValue.serverTimestamp(),
          });

          // Check if milestone is completed with this achievement
          if (currentCompletions + 1 >= target) {
            // Get reward details
            final rewardDoc = await _firestore
                .collection('sponsor_rewards')
                .doc(milestone['reward_id'])
                .get();

            if (rewardDoc.exists) {
              final rewardData = rewardDoc.data()!;
              final availableQuantity = rewardData['available_quantity'] as int;
              final rewardQuantity = milestone['reward_quantity'] as int;

              if (availableQuantity >= rewardQuantity) {
                // Update reward quantity
                await rewardDoc.reference.update({
                  'available_quantity': FieldValue.increment(-rewardQuantity),
                });

                // Record reward allocation
                await _firestore.collection('milestone_rewards').add({
                  'milestone_id': milestoneDoc.id,
                  'reward_id': milestone['reward_id'],
                  'quantity': rewardQuantity,
                  'allocated_at': FieldValue.serverTimestamp(),
                  'sponsor_id': sponsorId,
                  'status': 'allocated',
                });

                // Update milestone status
                await milestoneDoc.reference.update({
                  'status': 'completed',
                  'completed_at': FieldValue.serverTimestamp(),
                });
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error checking milestones: $e');
    }
  }

  // Get milestone progress for a specific user
  Future<List<Map<String, dynamic>>> getUserMilestoneProgress(String userId) async {
    final achievements = await _firestore
        .collection('milestone_achievements')
        .where('user_id', isEqualTo: userId)
        .get();

    final List<Map<String, dynamic>> progress = [];
    
    for (var achievement in achievements.docs) {
      final milestoneDoc = await _firestore
          .collection('sponsor_milestones')
          .doc(achievement.data()['milestone_id'])
          .get();

      if (milestoneDoc.exists) {
        progress.add({
          'milestone': milestoneDoc.data(),
          'achievement': achievement.data(),
        });
      }
    }

    return progress;
  }

  // Get rewards earned through milestones
  Future<List<Map<String, dynamic>>> getMilestoneRewards(String sponsorId) async {
    final rewards = await _firestore
        .collection('milestone_rewards')
        .where('sponsor_id', isEqualTo: sponsorId)
        .orderBy('allocated_at', descending: true)
        .get();

    final List<Map<String, dynamic>> rewardsList = [];

    for (var reward in rewards.docs) {
      final milestoneDoc = await _firestore
          .collection('sponsor_milestones')
          .doc(reward.data()['milestone_id'])
          .get();

      final rewardDoc = await _firestore
          .collection('sponsor_rewards')
          .doc(reward.data()['reward_id'])
          .get();

      if (milestoneDoc.exists && rewardDoc.exists) {
        rewardsList.add({
          'allocation': reward.data(),
          'milestone': milestoneDoc.data(),
          'reward': rewardDoc.data(),
        });
      }
    }

    return rewardsList;
  }
}