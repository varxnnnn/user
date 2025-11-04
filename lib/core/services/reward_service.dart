// lib/core/services/reward_service.dart

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
          // Extract voucher metadata
          final voucher = rewardData['metadata']?['voucher'] as Map<String, dynamic>? ?? {};
          
          rewards.add({
            "id": rewardId,
            "title": rewardData['title'] ?? "Reward",
            "description": rewardData['description'] ?? "",
            "image": rewardData['image_url'] ?? "https://via.placeholder.com/400/4ECDC4/FFFFFF?text=Voucher",
            "cost_points": rewardData['cost_points'] ?? 0,
            "status": data['status'] ?? "pending",
            "voucher_currency": voucher['currency'] ?? "INR",
            "voucher_value": voucher['value'] ?? 0,
            "sponsor_id": voucher['sponsor_id'] ?? "",
            "created_at": rewardData['created_at'] ?? DateTime.now(),
            "available_quantity": rewardData['available_quantity'] ?? 0,
            "total_quantity": rewardData['total_quantity'] ?? 0,
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

  // Fetch full details of a single reward by ID (for detail screen)
  Future<Map<String, dynamic>?> fetchRewardById(String rewardId) async {
    try {
      final doc = await _firestore.collection('sponsor_rewards').doc(rewardId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final voucher = data['metadata']?['voucher'] as Map<String, dynamic>? ?? {};

      return {
        "id": doc.id,
        "title": data['title'] ?? "Reward",
        "description": data['description'] ?? "",
        "image": data['image_url'] ?? "https://via.placeholder.com/400/4ECDC4/FFFFFF?text=Voucher",
        "cost_points": data['cost_points'] ?? 0,
        "status": data['status'] ?? "active",
        "voucher_currency": voucher['currency'] ?? "INR",
        "voucher_value": voucher['value'] ?? 0,
        "sponsor_id": voucher['sponsor_id'] ?? "",
        "created_at": data['created_at'] ?? DateTime.now(),
        "available_quantity": data['available_quantity'] ?? 0,
        "total_quantity": data['total_quantity'] ?? 0,
      };
    } catch (e) {
      print("❌ Error fetching reward detail: $e");
      return null;
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
        final voucher = data['metadata']?['voucher'] as Map<String, dynamic>? ?? {};
        return {
          "title": data['title'] ?? "Reward",
          "image": data['image_url'] ?? "https://via.placeholder.com/40/4ECDC4/FFFFFF?text=R",
          "cost_points": data['cost_points'] ?? 0,
          "status": "available",
          "voucher_currency": voucher['currency'] ?? "INR",
          "voucher_value": voucher['value'] ?? 0,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }
}