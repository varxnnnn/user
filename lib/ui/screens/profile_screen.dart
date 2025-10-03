// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/profile_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const ProfileScreen(),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProfileProvider>(context, listen: false).loadProfile();
    });
  }

  void _onCopyReferralCode(ProfileProvider provider) {
    final code = provider.userData?['referralCode'];
    if (code != null) {
      Clipboard.setData(ClipboardData(text: code.toString()));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Referral code copied!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ProfileProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // ✅ Only use fields from your schema
          final name = provider.userData?['name'] ?? "User Name";
          final email = provider.userData?['email'] ?? "email@example.com";
          final points = provider.userData?['points'] ?? 0;
          final referralCode = provider.userData?['referralCode'] ?? "XXXX";
          final totalRewards = provider.userData?['totalRewards'] ?? 0; // ✅ From reward_redemptions_report

          // Level based on points
          final currentLevel = (points ~/ 1000) + 1;

          double screenWidth = MediaQuery.of(context).size.width;
          double screenHeight = MediaQuery.of(context).size.height;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenHeight * 0.03),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                  child: Row(
                    children: [
                      Text("BestThings", style: TextStyle(fontSize: screenWidth * 0.07, fontWeight: FontWeight.bold, color: Colors.black)),
                      Text("Free", style: TextStyle(fontSize: screenWidth * 0.07, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),

                // User Info Card
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.03),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: screenWidth * 0.1,
                        backgroundColor: Colors.orange,
                        child: Text(
                          name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.03),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: TextStyle(fontSize: screenWidth * 0.05, fontWeight: FontWeight.w600, color: Colors.black)),
                            Text(email, style: TextStyle(fontSize: screenWidth * 0.035, color: Colors.grey)),
                            Text("Level $currentLevel", style: TextStyle(fontSize: screenWidth * 0.035, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),

                // Stats Cards
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard(
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                      icon: Icons.person_outline,
                      label: "Current Level",
                      value: "$currentLevel",
                    ),
                    _buildStatCard(
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                      icon: Icons.card_giftcard,
                      label: "Total Rewards Earned", // ✅ Updated
                      value: "$totalRewards",         // ✅ Real value
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.02),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard(
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                      icon: Icons.wallet,
                      label: "Current Wallet",
                      value: "$points",
                    ),
                    _buildStatCard(
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                      icon: Icons.star,
                      label: "Total Points",
                      value: "${points.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match.group(1)},')}",
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.03),

                // Invite Friends Section
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.03),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Invite Friends", style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.w600, color: Colors.black)),
                      SizedBox(height: screenHeight * 0.01),
                      Text("Share your referral code and earn bonus points", style: TextStyle(fontSize: screenWidth * 0.03, color: Colors.grey)),
                      SizedBox(height: screenHeight * 0.01),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                referralCode,
                                style: TextStyle(fontSize: screenWidth * 0.035, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          ElevatedButton(
                            onPressed: () => _onCopyReferralCode(provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: Text("Copy", style: TextStyle(fontSize: screenWidth * 0.035)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),

                // Settings & Preferences
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.03),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Settings & Preferences", style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.w600, color: Colors.black)),
                      SizedBox(height: screenHeight * 0.02),
                      Row(
                        children: [
                          Text("Language Selection", style: TextStyle(fontSize: screenWidth * 0.035, color: Colors.black)),
                          const Spacer(),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () => provider.updateLanguage("English"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: provider.selectedLanguage == "English" ? Colors.orange : Colors.grey[200],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                child: Text("English", style: TextStyle(fontSize: screenWidth * 0.03)),
                              ),
                              SizedBox(width: screenWidth * 0.02),
                              ElevatedButton(
                                onPressed: () => provider.updateLanguage("Hindi"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: provider.selectedLanguage == "Hindi" ? Colors.orange : Colors.grey[200],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                child: Text("Hindi", style: TextStyle(fontSize: screenWidth * 0.03)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      Row(
                        children: [
                          Text("Get notified about new activities", style: TextStyle(fontSize: screenWidth * 0.035, color: Colors.black)),
                          const Spacer(),
                          Switch(
                            value: provider.isNotified,
                            onChanged: provider.toggleNotifications,
                            activeColor: Colors.orange,
                          ),
                        ],
                      ),
                    ],
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

  Widget _buildStatCard({
    required double screenWidth,
    required double screenHeight,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: screenWidth * 0.45,
      padding: EdgeInsets.all(screenWidth * 0.02),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.orange, size: screenWidth * 0.06),
          SizedBox(height: screenHeight * 0.01),
          Text(value, style: TextStyle(fontSize: screenWidth * 0.05, fontWeight: FontWeight.w600, color: Colors.black)),
          SizedBox(height: screenHeight * 0.005),
          Text(label, style: TextStyle(fontSize: screenWidth * 0.03, color: Colors.grey)),
        ],
      ),
    );
  }
}