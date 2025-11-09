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
      final List<Map<String, dynamic>> rewards = [];

      // 1. Fetch rewards from rewards_earned collection (activity rewards)
      // Fetch both claimed and unclaimed rewards
      final rewardsEarnedSnapshot = await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('rewards_earned')
          .orderBy('timestamp', descending: true)
          .get();

      print("✅ Found ${rewardsEarnedSnapshot.docs.length} rewards earned from activities");

      for (var doc in rewardsEarnedSnapshot.docs) {
        final data = doc.data();
        final rewardId = data['reward_id']?.toString()?.trim();
        final activityId = data['activity_id']?.toString()?.trim();
        final rewardType = data['reward_type'] as String? ?? 'points';
        final rewardTitle = data['reward_title'] as String? ?? 'Reward';
        final rewardDescription = data['reward_description'] as String? ?? '';
        final rewardValue = data['reward_value'] as int? ?? 0;
        final rewardCode = data['reward_code'] as String? ?? '';
        final isLuckyDrawWinner = data['is_lucky_draw_winner'] as bool? ?? false;
        final status = data['status'] as String? ?? 'issued';

        Map<String, dynamic> rewardInfo = {
          "id": doc.id,
          "title": rewardTitle,
          "description": rewardDescription,
          "image": "https://via.placeholder.com/400/4ECDC4/FFFFFF?text=Reward",
          "cost_points": rewardValue,
          "status": status, // 'issued' or 'claimed'
          "type": rewardType,
          "reward_value": rewardValue,
          "reward_code": rewardCode,
          "activity_id": activityId ?? "",
          "is_lucky_draw_winner": isLuckyDrawWinner,
          "timestamp": data['timestamp'],
          "issued_at": data['issued_at'],
          "claimed_at": data['claimed_at'],
        };

        // Fetch reward details if rewardId exists
        if (rewardId != null && rewardId.isNotEmpty) {
          try {
            final rewardDoc = await _firestore
                .collection('sponsor_rewards')
                .doc(rewardId)
                .get();

            if (rewardDoc.exists) {
              final rewardData = rewardDoc.data()!;
              final metadata = rewardData['metadata'] as Map<String, dynamic>? ?? {};
              
              rewardInfo['image'] = rewardData['image_url'] ?? rewardInfo['image'];
              rewardInfo['sponsor_id'] = rewardData['sponsor_id'] ?? "";
              
              // Add type-specific metadata
              if (rewardType == 'voucher') {
                final voucher = metadata['voucher'] as Map<String, dynamic>? ?? {};
                rewardInfo.addAll({
                  "voucher_currency": voucher['currency'] ?? "INR",
                  "voucher_value": voucher['value'] ?? 0,
                });
              } else if (rewardType == 'product') {
                final product = metadata['product'] as Map<String, dynamic>? ?? {};
                rewardInfo.addAll({
                  "product_name": product['name'] ?? "Product",
                  "product_brand": product['brand'] ?? "",
                  "product_model": product['model'] ?? "",
                  "product_category": product['category'] ?? "",
                  "product_price": product['price'] ?? 0.0,
                  "product_description": product['description'] ?? "",
                });
              } else if (rewardType == 'coins' || rewardType == 'points') {
                rewardInfo['coins_amount'] = rewardValue;
              }
            }
          } catch (e) {
            print("⚠️ Error fetching reward details for reward $rewardId: $e");
          }
        }

        // Fetch activity details if activityId exists
        if (activityId != null && activityId.isNotEmpty) {
          try {
            final activityDoc = await _firestore
                .collection('sponsor_activities')
                .doc(activityId)
                .get();
            
            if (activityDoc.exists) {
              final activityData = activityDoc.data()!;
              rewardInfo.addAll({
                "activity_title": activityData['title'] ?? "Activity",
                "activity_description": activityData['description'] ?? "",
                "reward_distribution_type": activityData['reward_distribution_type'] ?? "first_come_first_serve",
                "start_date": activityData['start_date'],
                "end_date": activityData['end_date'],
              });
            }
          } catch (e) {
            print("⚠️ Error fetching activity details for activity $activityId: $e");
          }
        }

        rewards.add(rewardInfo);
      }

      // 2. Also fetch from redemptions collection (for backward compatibility)
      final redemptionSnapshot = await _firestore
          .collection('redemptions')
          .where('user_id', isEqualTo: currentUid)
          .get();

      print("✅ Found ${redemptionSnapshot.docs.length} redemptions");

      for (var redemption in redemptionSnapshot.docs) {
        final data = redemption.data();
        final rewardId = data['reward_id']?.toString()?.trim();
        final activityId = data['activity_id']?.toString()?.trim();

        if (rewardId == null || rewardId.isEmpty) continue;

        // Check if already added from rewards_earned
        if (rewards.any((r) => r['id'] == rewardId && r['activity_id'] == activityId)) {
          continue;
        }

        final rewardDoc = await _firestore
            .collection('sponsor_rewards')
            .doc(rewardId)
            .get();

        if (rewardDoc.exists) {
          final rewardData = rewardDoc.data()!;
          final metadata = rewardData['metadata'] as Map<String, dynamic>? ?? {};
          final rewardType = rewardData['type'] as String? ?? 'voucher';
          
          Map<String, dynamic> rewardInfo = {
            "id": rewardId,
            "title": rewardData['title'] ?? "Reward",
            "description": rewardData['description'] ?? "",
            "image": rewardData['image_url'] ?? "https://via.placeholder.com/400/4ECDC4/FFFFFF?text=Voucher",
            "cost_points": rewardData['cost_points'] ?? 0,
            "status": data['status'] ?? "pending",
            "type": rewardType,
            "sponsor_id": rewardData['sponsor_id'] ?? "",
            "created_at": rewardData['created_at'] ?? DateTime.now(),
            "available_quantity": rewardData['available_quantity'] ?? 0,
            "total_quantity": rewardData['total_quantity'] ?? 0,
            "activity_id": activityId ?? "",
          };
          
          // Add type-specific metadata
          if (rewardType == 'voucher') {
            final voucher = metadata['voucher'] as Map<String, dynamic>? ?? {};
            rewardInfo.addAll({
              "voucher_currency": voucher['currency'] ?? "INR",
              "voucher_value": voucher['value'] ?? 0,
            });
          } else if (rewardType == 'product') {
            final product = metadata['product'] as Map<String, dynamic>? ?? {};
            rewardInfo.addAll({
              "product_name": product['name'] ?? "Product",
              "product_brand": product['brand'] ?? "",
              "product_model": product['model'] ?? "",
              "product_category": product['category'] ?? "",
              "product_price": product['price'] ?? 0.0,
              "product_description": product['description'] ?? "",
            });
          } else if (rewardType == 'coins') {
            final coins = metadata['coins'] as Map<String, dynamic>? ?? {};
            rewardInfo.addAll({
              "coins_amount": coins['amount'] ?? 0,
            });
          }
          
          // If this reward is from an activity, fetch activity details
          if (activityId != null && activityId.isNotEmpty) {
            try {
              final activityDoc = await _firestore
                  .collection('sponsor_activities')
                  .doc(activityId)
                  .get();
              
              if (activityDoc.exists) {
                final activityData = activityDoc.data()!;
                rewardInfo.addAll({
                  "activity_title": activityData['title'] ?? "Activity",
                  "activity_description": activityData['description'] ?? "",
                  "reward_distribution_type": activityData['reward_distribution_type'] ?? "first_come_first_serve",
                  "start_date": activityData['start_date'],
                  "end_date": activityData['end_date'],
                });
              }
            } catch (e) {
              print("⚠️ Error fetching activity details for reward $rewardId: $e");
            }
          }

          rewards.add(rewardInfo);
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
      final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
      final rewardType = data['type'] as String? ?? 'voucher';
      
      Map<String, dynamic> rewardInfo = {
        "id": doc.id,
        "title": data['title'] ?? "Reward",
        "description": data['description'] ?? "",
        "image": data['image_url'] ?? "https://via.placeholder.com/400/4ECDC4/FFFFFF?text=Voucher",
        "cost_points": data['cost_points'] ?? 0,
        "status": data['status'] ?? "active",
        "type": rewardType,
        "sponsor_id": data['sponsor_id'] ?? "",
        "created_at": data['created_at'] ?? DateTime.now(),
        "available_quantity": data['available_quantity'] ?? 0,
        "total_quantity": data['total_quantity'] ?? 0,
      };
      
      // Add type-specific metadata
      if (rewardType == 'voucher') {
        final voucher = metadata['voucher'] as Map<String, dynamic>? ?? {};
        rewardInfo.addAll({
          "voucher_currency": voucher['currency'] ?? "INR",
          "voucher_value": voucher['value'] ?? 0,
        });
      } else if (rewardType == 'product') {
        final product = metadata['product'] as Map<String, dynamic>? ?? {};
        rewardInfo.addAll({
          "product_name": product['name'] ?? "Product",
          "product_brand": product['brand'] ?? "",
          "product_model": product['model'] ?? "",
          "product_category": product['category'] ?? "",
          "product_price": product['price'] ?? 0.0,
          "product_description": product['description'] ?? "",
        });
      } else if (rewardType == 'coins') {
        final coins = metadata['coins'] as Map<String, dynamic>? ?? {};
        rewardInfo.addAll({
          "coins_amount": coins['amount'] ?? 0,
        });
      }

      return rewardInfo;
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
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        final rewardType = data['type'] as String? ?? 'voucher';
        
        Map<String, dynamic> rewardInfo = {
          "title": data['title'] ?? "Reward",
          "image": data['image_url'] ?? "https://via.placeholder.com/40/4ECDC4/FFFFFF?text=R",
          "cost_points": data['cost_points'] ?? 0,
          "status": "available",
          "type": rewardType,
        };
        
        // Add type-specific metadata
        if (rewardType == 'voucher') {
          final voucher = metadata['voucher'] as Map<String, dynamic>? ?? {};
          rewardInfo.addAll({
            "voucher_currency": voucher['currency'] ?? "INR",
            "voucher_value": voucher['value'] ?? 0,
          });
        } else if (rewardType == 'product') {
          final product = metadata['product'] as Map<String, dynamic>? ?? {};
          rewardInfo.addAll({
            "product_name": product['name'] ?? "Product",
            "product_brand": product['brand'] ?? "",
            "product_category": product['category'] ?? "",
          });
        } else if (rewardType == 'coins') {
          final coins = metadata['coins'] as Map<String, dynamic>? ?? {};
          rewardInfo.addAll({
            "coins_amount": coins['amount'] ?? 0,
          });
        }
        
        return rewardInfo;
      }).toList();
    } catch (e) {
      return [];
    }
  }
}