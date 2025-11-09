import 'package:cloud_firestore/cloud_firestore.dart';

class RewardClaimService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Claims a reward that was issued to the user
  Future<Map<String, dynamic>?> claimReward({
    required String userId,
    required String activityId,
  }) async {
    try {
      // Get the reward from rewards_earned
      final rewardDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('rewards_earned')
          .doc(activityId)
          .get();

      if (!rewardDoc.exists) {
        throw Exception('Reward not found');
      }

      final rewardData = rewardDoc.data()!;
      final status = rewardData['status'] as String?;

      if (status == 'claimed') {
        throw Exception('Reward already claimed');
      }

      if (status != 'issued') {
        throw Exception('Reward is not available for claiming');
      }

      final rewardType = rewardData['reward_type'] as String? ?? 'points';
      final rewardValue = rewardData['reward_value'] as int? ?? 0;

      // Update status to claimed
      await rewardDoc.reference.update({
        'status': 'claimed',
        'claimed_at': FieldValue.serverTimestamp(),
      });

      // Apply the reward (add coins/points to user wallet)
      if (['coins', 'points'].contains(rewardType)) {
        if (rewardValue > 0) {
          await _firestore.collection('users').doc(userId).update({
            'points': FieldValue.increment(rewardValue),
          });
        }
      }

      return {
        'success': true,
        'reward_type': rewardType,
        'reward_value': rewardValue,
        'status': 'claimed',
      };
    } catch (e) {
      print('Error claiming reward: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Gets all unclaimed rewards for a user
  Future<List<Map<String, dynamic>>> getUnclaimedRewards(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('rewards_earned')
          .where('status', isEqualTo: 'issued')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error fetching unclaimed rewards: $e');
      return [];
    }
  }

  /// Gets all claimed rewards for a user
  Future<List<Map<String, dynamic>>> getClaimedRewards(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('rewards_earned')
          .where('status', isEqualTo: 'claimed')
          .orderBy('claimed_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error fetching claimed rewards: $e');
      return [];
    }
  }
}

