import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RewardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchUserRewards() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("⚠️ No authenticated user");
      return [];
    }

    final String currentUid = user.uid;
    print("🔍 fetchUserRewards() for UID: $currentUid");

    try {
      final redemptionSnapshot = await _firestore
          .collection('redemptions')
          .where('user_id', isEqualTo: currentUid)
          .get();

      print("✅ Found ${redemptionSnapshot.docs.length} redemptions");

      final List<Map<String, dynamic>> rewards = [];
      for (var redemption in redemptionSnapshot.docs) {
        final data = redemption.data();
        final rewardId = data['reward_id']?.toString()?.trim();

        if (rewardId == null || rewardId.isEmpty) continue;

        final rewardDoc = await _firestore
            .collection('sponsor_rewards')
            .doc(rewardId)
            .get();

        if (rewardDoc.exists) {
          final rewardData = rewardDoc.data()!;
          rewards.add({
            "title": rewardData['title'] ?? "Reward",
            "image": "https://via.placeholder.com/40/4ECDC4/FFFFFF?text=R",
            "cost_points": rewardData['cost_points'] ?? 0,
            "status": data['status'] ?? "pending",
          });
        }
      }

      print("🎉 Returning ${rewards.length} rewards");
      return rewards;
    } catch (e, stack) {
      print("💥 Error: $e");
      return [];
    }
  }

  // Keep this for fallback or admin view
  Future<List<Map<String, dynamic>>> fetchAllRewards() async {
    try {
      final snapshot = await _firestore
          .collection('sponsor_rewards')
          .where('status', isEqualTo: 'active')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          "title": data['title'] ?? "Reward",
          "image": "https://via.placeholder.com/40/4ECDC4/FFFFFF?text=R",
          "cost_points": data['cost_points'] ?? 0,
          "status": "available",
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }
}