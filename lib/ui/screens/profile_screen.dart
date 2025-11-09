import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/profile_provider.dart';
import 'package:giftardo/providers/auth_provider.dart';
import '../components/loading_components.dart';
import '../components/reward_history_widget.dart';
import 'reward_history_full_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  Future<void> _logout(BuildContext context) async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      try {
        // Sign out using AuthProvider - AuthWrapper will handle navigation automatically
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.signOut();

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logged out successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // Show error message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

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

  // 👇 Helper to get profile image URL
  String? _getProfileImageUrl(String? userId) {
    if (userId == null) return null;

    // Use Uri.encodeComponent instead of Uri.encodeFull
    final path = 'profiles/$userId.jpg';
    final encodedPath = Uri.encodeComponent(path);

    return 'https://firebasestorage.googleapis.com/v0/b/giftardo-43381.firebasestorage.app/o/$encodedPath?alt=media';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ProfileProvider>(
        builder: (context, provider, child) {
          double screenWidth = MediaQuery.of(context).size.width;
          double screenHeight = MediaQuery.of(context).size.height;

          if (provider.isLoading) {
            return LoadingComponents.profileScreenLoading(
              screenWidth,
              screenHeight,
            );
          }

          final name = provider.userData?['name'] ?? "User Name";
          final email = provider.userData?['email'] ?? "email@example.com";
          final points = provider.userData?['points'] ?? 0;
          final referralCode = provider.userData?['referralCode'] ?? "XXXX";
          final totalRewards = provider.userData?['totalRewards'] ?? 0;
          final currentLevel = (points ~/ 1000) + 1;

          // 👇 Get image URL
          final profileImageUrl = _getProfileImageUrl(provider.userId);

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      // 👇 Replaced CircleAvatar content with CachedNetworkImage
                      CircleAvatar(
                        radius: screenWidth * 0.1,
                        backgroundColor: Colors.orange,
                        child: profileImageUrl != null
                            ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: profileImageUrl,
                            fit: BoxFit.cover,
                            width: screenWidth * 0.2,
                            height: screenWidth * 0.2,
                            placeholder: (context, url) => const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                            errorWidget: (context, url, error) =>
                                _buildInitialsAvatar(name),
                          ),
                        )
                            : _buildInitialsAvatar(name),
                      ),
                      SizedBox(width: screenWidth * 0.03),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: screenWidth * 0.05,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: screenWidth * 0.035,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              "Level $currentLevel",
                              style: TextStyle(
                                fontSize: screenWidth * 0.035,
                                color: Colors.grey,
                              ),
                            ),
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
                      label: "Total Rewards Earned",
                      value: "$totalRewards",
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
                      Text(
                        "Invite Friends",
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Text(
                        "Share your referral code and earn bonus points",
                        style: TextStyle(
                          fontSize: screenWidth * 0.03,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                referralCode,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          ElevatedButton(
                            onPressed: () => _onCopyReferralCode(provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              "Copy",
                              style: TextStyle(fontSize: screenWidth * 0.035),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                
                // Reward History Section (Recent 5)
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.03),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Reward History",
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RewardHistoryFullPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "View All",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      const RewardHistoryWidget(limit: 5),
                    ],
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                
                // Logout Button
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  child: ElevatedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.shade200, width: 1.5),
                      ),
                    ),
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

  // 👇 Helper to build initials fallback
  Widget _buildInitialsAvatar(String name) {
    return Text(
      name.length >= 2
          ? name.substring(0, 2).toUpperCase()
          : name.toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 24,
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
          Text(
            value,
            style: TextStyle(
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          SizedBox(height: screenHeight * 0.005),
          Text(
            label,
            style: TextStyle(fontSize: screenWidth * 0.03, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}