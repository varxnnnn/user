// lib/screens/reward_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/reward_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RewardDetailScreen extends StatelessWidget {
  final String rewardId;

  const RewardDetailScreen({Key? key, required this.rewardId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SafeArea(
        child: Consumer<RewardProvider>(
          builder: (context, provider, child) {
            if (provider.currentRewardDetail == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                provider.loadRewardDetail(rewardId);
              });
              return const Center(child: CircularProgressIndicator());
            }

            final reward = provider.currentRewardDetail!;

            return SingleChildScrollView(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔙 Back button
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Reward Details",
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.03),

                  // 🎁 Hero Image
                  Hero(
                    tag: "reward_${reward['id']}",
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: reward['image'] ?? "",
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: screenHeight * 0.3,
                        placeholder: (context, url) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.image_not_supported,
                                size: 40, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),

                  // 🏷 Title
                  Text(
                    reward['title'] ?? '',
                    style: TextStyle(
                      fontSize: screenWidth * 0.055,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),

                  // 📜 Description
                  Text(
                    reward['description'] ?? '',
                    style: TextStyle(
                      fontSize: screenWidth * 0.037,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.justify,
                  ),
                  SizedBox(height: screenHeight * 0.02),

                  // 💰 Voucher Value
                  _buildInfoCard(
                    screenWidth,
                    "Voucher Value",
                    "${reward['voucher_currency']} ${reward['voucher_value']}",
                    Colors.orange,
                  ),
                  SizedBox(height: screenHeight * 0.02),

                  // 💎 Points Required
                  _buildInfoCard(
                    screenWidth,
                    "Points Required",
                    "${reward['cost_points'] ?? 0}",
                    Colors.blue,
                  ),
                  SizedBox(height: screenHeight * 0.03),

                  // Status + Quantity
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniCard(
                          screenWidth,
                          "Status",
                          reward['status'] ?? 'Active',
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniCard(
                          screenWidth,
                          "Available",
                          "${reward['available_quantity']}/${reward['total_quantity'] ?? reward['available_quantity']}",
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.03),

                  // 🧭 Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _onClaimPressed(context, rewardId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            "Claim Voucher",
                            style: TextStyle(fontSize: screenWidth * 0.045),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _onDeletePressed(context, rewardId), // ✅ fixed
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            "Delete",
                            style: TextStyle(fontSize: screenWidth * 0.045),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.03),

                  Center(
                    child: Text(
                      "Redeemable via sponsor app or website.",
                      style: TextStyle(
                        fontSize: screenWidth * 0.03,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // -------------------
  // 🔧 Helper widgets
  // -------------------

  Widget _buildInfoCard(
      double width, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(width * 0.03),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: width * 0.037,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              )),
          Text(value,
              style: TextStyle(
                fontSize: width * 0.045,
                fontWeight: FontWeight.bold,
                color: color,
              )),
        ],
      ),
    );
  }

  Widget _buildMiniCard(
      double width, String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(width * 0.025),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(title,
    style: TextStyle(
      fontSize: width * 0.03,
      fontWeight: FontWeight.w500,
      color: color, // ✅ Fixed
    )),
const SizedBox(height: 4),
Text(
  value,
  style: TextStyle(
    fontSize: width * 0.035,
    fontWeight: FontWeight.bold,
    color: color, // ✅ Fixed
  ),
),

        ],
      ),
    );
  }

  // -------------------
  // 🧾 Action Functions
  // -------------------

  void _onClaimPressed(BuildContext context, String rewardId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Claim Successful!"),
        content: const Text("Your voucher has been successfully claimed."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _onDeletePressed(BuildContext context, String rewardId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Reward?"),
        content: const Text("Are you sure you want to delete this reward?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _deleteReward(context, rewardId); // ✅ pass context
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Reward deleted.")),
                );
                Navigator.pop(context); // Return to wallet
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReward(BuildContext context, String rewardId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestore = FirebaseFirestore.instance;
      final redemptionRef = firestore
          .collection('redemptions')
          .where('user_id', isEqualTo: user.uid)
          .where('reward_id', isEqualTo: rewardId);

      final snapshot = await redemptionRef.get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      // ✅ Safe context usage
      final provider = Provider.of<RewardProvider>(context, listen: false);
      await provider.loadRewards();
    } catch (e) {
      debugPrint("❌ Error deleting reward: $e");
    }
  }
}
