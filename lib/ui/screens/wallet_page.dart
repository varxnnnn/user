import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/wallet_provider.dart';
import 'package:giftardo/providers/reward_provider.dart';
import '../components/loading_components.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 NEW
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 NEW
import 'package:cached_network_image/cached_network_image.dart'; // 👈 NEW

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final String _rank = "#98";
  final bool _rankTrendUp = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _topWinners = [];
  bool _winnersLoading = true;

  // 👇 Helper to build Firebase Storage image URL
  String _getProfileImageUrl(String userId) {
    final path = 'profiles/$userId.jpg';
    final encodedPath = Uri.encodeComponent(path); // ✅ Correct encoding
    return 'https://firebasestorage.googleapis.com/v0/b/giftardo-43381.firebasestorage.app/o/$encodedPath?alt=media'; // ✅ No extra spaces!
  }

  // 👇 Build cached avatar with fallback
  Widget _buildCachedAvatar(String userId, String name, double radius) {
    final imageUrl = _getProfileImageUrl(userId);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
        placeholder: (context, url) => _buildInitials(initial, radius),
        errorWidget: (context, url, error) => _buildInitials(initial, radius),
      ),
    );
  }

  Widget _buildInitials(String initial, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.orange,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  Future<void> _fetchTopWinners() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('points', descending: true)
          .limit(3)
          .get();
      final List<Map<String, dynamic>> winners = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        winners.add({
          'uid': doc.id,
          'name': data['name'] ?? 'User',
        });
      }
      setState(() {
        _topWinners = winners;
        _winnersLoading = false;
      });
    } catch (e) {
      setState(() {
        _topWinners = [];
        _winnersLoading = false;
      });
    }
  }

  void _onInvitePressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invite sent!")),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RewardProvider>(context, listen: false).loadRewards();
      _fetchTopWinners();
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    final currentUser = _auth.currentUser;
    final currentUserId = currentUser?.uid;
    final currentUserEmail = currentUser?.email ?? "User";
    final currentUserInitial = currentUserEmail.isNotEmpty
        ? currentUserEmail[0].toUpperCase()
        : 'U';

    return Scaffold(
      body: Consumer2<WalletProvider, RewardProvider>(
        builder: (context, walletProvider, rewardProvider, child) {
          // Earned badges removed — no local badge list needed

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenHeight * 0.03),
                Row(
                  children: [
                    Text(
                      "Giftardo",
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.02),

                // Profile & Wallet Card — 👇 Updated Avatar
                Row(
                  children: [
                    currentUserId != null
                        ? _buildCachedAvatar(currentUserId, currentUserInitial, screenWidth * 0.1)
                        : const CircleAvatar(
                      radius: 30,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    SizedBox(width: screenWidth * 0.03),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(screenWidth * 0.03),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "My Wallet",
                              style: TextStyle(
                                fontSize: screenWidth * 0.045,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.01),
                            Row(
                              children: [
                                Icon(Icons.monetization_on, size: 18, color: Colors.orange),
                                SizedBox(width: 4),
                                Text(
                                  "${walletProvider.walletAmount}",
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.05,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple[500],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: screenHeight * 0.01),
                            Row(
                              children: [
                                Text(_rank, style: TextStyle(fontSize: screenWidth * 0.035, color: Colors.grey)),
                                SizedBox(width: 4),
                                Icon(
                                  _rankTrendUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                  color: _rankTrendUp ? Colors.green : Colors.red,
                                  size: 16,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.03),

                // Earned Badges section removed as requested

                // My Rewards
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "My Rewards",
                      style: TextStyle(
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        "View all",
                        style: TextStyle(fontSize: screenWidth * 0.03, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.01),
                SizedBox(
                  width: double.infinity,
                  child: rewardProvider.isLoading
                      ? LoadingComponents.gridLoading(
                          screenWidth: screenWidth,
                          screenHeight: screenHeight,
                          crossAxisCount: 2,
                          itemCount: 4,
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rewardProvider.rewards.length,
                          itemBuilder: (context, index) {
                            final reward = rewardProvider.rewards[index];
                            return Container(
                              margin: EdgeInsets.only(bottom: screenWidth * 0.02),
                              padding: EdgeInsets.all(screenWidth * 0.03),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.orange.shade200),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                              ),
                              child: Row(
                                children: [
                                  // Image placeholders removed per request — show a simple icon instead
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.orange[100],
                                      borderRadius: BorderRadius.circular(50),
                                      border: Border.all(color: Colors.orange[300]!),
                                    ),
                                    child: const Icon(Icons.card_giftcard, color: Colors.orange),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      reward['title'] ?? '',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.037,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                SizedBox(height: screenHeight * 0.03),

                // 🔸 Top Winners Today — 👇 ADDED REAL SECTION
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Top Winners Today",
                      style: TextStyle(
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _onInvitePressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text("Invite", style: TextStyle(fontSize: screenWidth * 0.035)),
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  "Invite Friends to Earn More Freebies",
                  style: TextStyle(fontSize: screenWidth * 0.03, color: Colors.grey),
                ),
                SizedBox(height: screenHeight * 0.02),

                // 👇 Real Top Winners Avatars
                _winnersLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _topWinners.length,
                    itemBuilder: (context, index) {
                      final winner = _topWinners[index];
                      final name = winner['name'] as String;
                      final uid = winner['uid'] as String;
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Column(
                          children: [
                            _buildCachedAvatar(uid, name, 25),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 80,
                              child: Text(
                                name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: screenHeight * 0.05),
              ],
            ),
          );
        },
      ),
    );
  }
}