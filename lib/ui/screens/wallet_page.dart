import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/wallet_provider.dart';
import 'package:giftardo/providers/reward_provider.dart'; // 👈 NEW
import '../components/loading_components.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final String _rank = "#98";
  final bool _rankTrendUp = true;

  // REMOVE dummy _badges and _rewards

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
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Consumer2<WalletProvider, RewardProvider>(
        builder: (context, walletProvider, rewardProvider, child) {
          // Keep dummy badges (no schema provided for badges)
          final _badges = [
            "https://via.placeholder.com/60/FF6B6B/FFFFFF?text=B1",
            "https://via.placeholder.com/60/4ECDC4/FFFFFF?text=B2",
            "https://via.placeholder.com/60/45B7D1/FFFFFF?text=B3",
            "https://via.placeholder.com/60/E67E22/FFFFFF?text=B4",
          ];

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenHeight * 0.03),
                Row(
                  children: [
                    Text("Giftardo", style: TextStyle(fontSize: screenWidth * 0.05, fontWeight: FontWeight.bold, color: Colors.black)),
                    // Text("Free", style: TextStyle(fontSize: screenWidth * 0.05, fontWeight: FontWeight.bold, color: Colors.orange)),
                  ],
                ),
                SizedBox(height: screenHeight * 0.02),

                // Profile & Wallet Card
                Row(
                  children: [
                    CircleAvatar(
                      radius: screenWidth * 0.1,
                      backgroundImage: NetworkImage("https://via.placeholder.com/100/FF6B6B/FFFFFF?text=AR"),
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
                            Text("My Wallet", style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.w600, color: Colors.black)),
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

                // Earned Badges (dummy - no schema)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Earned Badges", style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.w600, color: Colors.black)),
                    TextButton(onPressed: () {}, child: Text("View all", style: TextStyle(fontSize: screenWidth * 0.03, color: Colors.blue))),
                  ],
                ),
                SizedBox(height: screenHeight * 0.01),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: screenWidth * 0.02,
                    runSpacing: screenWidth * 0.02,
                    children: _badges.map((badge) {
                      return Container(
                        width: screenWidth * 0.15,
                        height: screenWidth * 0.15,
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: Center(
                          child: Image.network(
                            badge.trim(),
                            width: screenWidth * 0.1,
                            height: screenWidth * 0.1,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),

                // 🔸 My Rewards - FROM DATABASE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("My Rewards", style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.w600, color: Colors.black)),
                    TextButton(
                      onPressed: () {},
                      child: Text("View all", style: TextStyle(fontSize: screenWidth * 0.03, color: Colors.blue)),
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
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: screenWidth * 0.02,
                            mainAxisSpacing: screenWidth * 0.02,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: rewardProvider.rewards.length,
                          itemBuilder: (context, index) {
                            final reward = rewardProvider.rewards[index];
                            return Container(
                              padding: EdgeInsets.all(screenWidth * 0.02),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.orange.shade200),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.orange[100],
                                      borderRadius: BorderRadius.circular(50),
                                      border: Border.all(color: Colors.orange[300]!),
                                    ),
                                    child: Image.network(
                                      reward['image'].toString().trim(),
                                      width: 30,
                                      height: 30,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      reward['title'],
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.035,
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

                // Top Winners Today
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Top Winners Today", style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.w600, color: Colors.black)),
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
                Text("Invite Friends to Earn More Freebies", style: TextStyle(fontSize: screenWidth * 0.03, color: Colors.grey)),
                SizedBox(height: screenHeight * 0.05),
              ],
            ),
          );
        },
      ),
    );
  }
}