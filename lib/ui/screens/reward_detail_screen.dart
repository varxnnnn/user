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

                  // Display reward details based on type
                  if (reward['type'] == 'voucher') ...[
                    // 💰 Voucher Value
                    _buildInfoCard(
                      screenWidth,
                      "Voucher Value",
                      "${reward['voucher_currency']} ${reward['voucher_value']}",
                      Colors.orange,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                  ] else if (reward['type'] == 'product') ...[
                    // 📦 Product Details
                    _buildProductInfoCard(screenWidth, reward),
                    SizedBox(height: screenHeight * 0.02),
                  ] else if (reward['type'] == 'coins') ...[
                    // 💰 Coins Amount
                    _buildInfoCard(
                      screenWidth,
                      "Coins Amount",
                      "${reward['coins_amount']} coins",
                      Colors.orange,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                  ],

                  // 💎 Points Required
                  _buildInfoCard(
                    screenWidth,
                    "Points Required",
                    "${reward['cost_points'] ?? 0}",
                    Colors.blue,
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  
                  // 🎯 Activity Information
                  if (reward['activity_title'] != null &&
                      reward['activity_title'].toString().isNotEmpty) ...[
                    _buildInfoCard(
                      screenWidth,
                      "Activity",
                      reward['activity_title'],
                      Colors.purple,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    
                    // Reward Distribution Type
                    if (reward['reward_distribution_type'] != null) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          color: reward['reward_distribution_type'] == 'lucky_draw'
                              ? Colors.purple.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: reward['reward_distribution_type'] == 'lucky_draw'
                                ? Colors.purple.withOpacity(0.3)
                                : Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Reward Distribution",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: screenWidth * 0.01),
                            Text(
                              reward['reward_distribution_type'] == 'lucky_draw'
                                  ? 'Lucky Draw'
                                  : 'First Come First Serve',
                              style: TextStyle(
                                fontSize: screenWidth * 0.045,
                                fontWeight: FontWeight.bold,
                                color: reward['reward_distribution_type'] == 'lucky_draw'
                                    ? Colors.purple
                                    : Colors.green,
                              ),
                            ),
                            // Show dates if available
                            if (reward['start_date'] != null || reward['end_date'] != null) ...[
                              SizedBox(height: screenWidth * 0.02),
                              Text(
                                _formatActivityDates(reward['start_date'], reward['end_date']),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                    ],
                  ],

                  // 📅 Available Quantity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniCard(
                        screenWidth * 0.45,
                        "Available",
                        "${reward['available_quantity']}",
                        Colors.green,
                      ),
                      _buildMiniCard(
                        screenWidth * 0.45,
                        "Total",
                        "${reward['total_quantity']}",
                        Colors.grey,
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.05),

                  // 🎯 Claim Button
                  SizedBox(
                    width: double.infinity,
                    height: screenHeight * 0.07,
                    child: ElevatedButton(
                      onPressed: () => _onClaimPressed(context, rewardId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Claim Reward",
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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

  Widget _buildInfoCard(double width, String title, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: width * 0.035,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          SizedBox(height: width * 0.01),
          Text(
            value,
            style: TextStyle(
              fontSize: width * 0.045,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfoCard(double width, Map<String, dynamic> reward) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Product Details",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          if (reward['product_name'] != null)
            _buildProductDetailRow("Name", reward['product_name']),
          if (reward['product_brand'] != null)
            _buildProductDetailRow("Brand", reward['product_brand']),
          if (reward['product_model'] != null)
            _buildProductDetailRow("Model", reward['product_model']),
          if (reward['product_category'] != null)
            _buildProductDetailRow("Category", reward['product_category']),
          if (reward['product_price'] != null)
            _buildProductDetailRow("Price", "₹${reward['product_price']}"),
          if (reward['product_description'] != null)
            _buildProductDetailRow("Description", reward['product_description']),
        ],
      ),
    );
  }

  Widget _buildProductDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
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

  String _formatActivityDates(dynamic startDate, dynamic endDate) {
    try {
      DateTime? start, end;
      
      // Handle different date formats
      if (startDate is Timestamp) {
        start = startDate.toDate();
      } else if (startDate is DateTime) {
        start = startDate;
      }
      
      if (endDate is Timestamp) {
        end = endDate.toDate();
      } else if (endDate is DateTime) {
        end = endDate;
      }
      
      if (start != null && end != null) {
        return "${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}";
      } else if (start != null) {
        return "Starts: ${start.day}/${start.month}/${start.year}";
      } else if (end != null) {
        return "Ends: ${end.day}/${end.month}/${end.year}";
      }
      return "Dates not specified";
    } catch (e) {
      return "Date information unavailable";
    }
  }

  void _onClaimPressed(BuildContext context, String rewardId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Claim Successful!"),
        content: const Text("Your reward has been successfully claimed."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}