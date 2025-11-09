import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/wallet_provider.dart';
import 'package:giftardo/providers/reward_provider.dart';
import '../components/loading_components.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'redemption_screen.dart';
import 'package:giftardo/core/services/reward_claim_service.dart';
import 'package:giftardo/core/services/milestone_service.dart';
import 'package:intl/intl.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int? _userRank;
  final bool _rankTrendUp = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RewardClaimService _claimService = RewardClaimService();
  final MilestoneService _milestoneService = MilestoneService();

  List<Map<String, dynamic>> _topWinners = [];
  bool _winnersLoading = true;
  int _selectedTab = 0; // 0 = Yet to Claim, 1 = Claimed
  List<Map<String, dynamic>> _milestoneRewards = [];
  bool _milestoneRewardsLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RewardProvider>(context, listen: false).loadRewards();
      _fetchTopWinners();
      _fetchMilestoneRewards();
      _fetchUserRank();
    });
  }
  
  Future<void> _fetchMilestoneRewards() async {
    setState(() {
      _milestoneRewardsLoading = true;
    });
    
    try {
      final rewards = await _milestoneService.getMilestoneRewardsHistory();
      setState(() {
        _milestoneRewards = rewards;
        _milestoneRewardsLoading = false;
      });
    } catch (e) {
      setState(() {
        _milestoneRewards = [];
        _milestoneRewardsLoading = false;
      });
    }
  }
  
  Future<void> _fetchUserRank() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userPoints = userDoc.data()?['points'] ?? 0;
      
      final higherRankedUsers = await _firestore
          .collection('users')
          .where('points', isGreaterThan: userPoints)
          .get();
      
      setState(() {
        _userRank = higherRankedUsers.docs.length + 1;
      });
    } catch (e) {
      print('Error fetching user rank: $e');
      setState(() {
        _userRank = null;
      });
    }
  }

  // 👇 Fixed: Removed extra spaces in URL
  String _getProfileImageUrl(String userId) {
    final path = 'profiles/$userId.jpg';
    final encodedPath = Uri.encodeComponent(path);
    return 'https://firebasestorage.googleapis.com/v0/b/giftardo-43381.firebasestorage.app/o/$encodedPath?alt=media';
  }

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

  void _navigateToRedemption() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RedemptionScreen()),
    );
  }

  Widget _buildRewardsList(List<Map<String, dynamic>> rewards, double screenWidth, double screenHeight) {
    // Filter rewards based on selected tab
    final filteredRewards = rewards.where((reward) {
      final status = reward['status'] as String? ?? 'issued';
      if (_selectedTab == 0) {
        return status == 'issued'; // Yet to claim
      } else {
        return status == 'claimed'; // Claimed
      }
    }).toList();

    if (filteredRewards.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(screenHeight * 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedTab == 0 ? Icons.card_giftcard_outlined : Icons.check_circle_outline,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                _selectedTab == 0 
                    ? 'No rewards to claim yet' 
                    : 'No claimed rewards yet',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredRewards.length,
      itemBuilder: (context, index) {
        final reward = filteredRewards[index];
        return _buildRewardCard(reward, screenWidth, screenHeight);
      },
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> reward, double screenWidth, double screenHeight) {
    final status = reward['status'] as String? ?? 'issued';
    final isUnclaimed = status == 'issued';

    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.02),
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        border: Border.all(
          color: isUnclaimed ? Colors.orange.shade300 : Colors.green.shade300,
          width: isUnclaimed ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isUnclaimed ? Colors.orange.shade50 : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isUnclaimed ? Colors.orange[100] : Colors.green[100],
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: isUnclaimed ? Colors.orange[300]! : Colors.green[300]!,
                  ),
                ),
                child: Icon(
                  isUnclaimed ? Icons.card_giftcard : Icons.check_circle,
                  color: isUnclaimed ? Colors.orange : Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward['title'] ?? 'Reward',
                      style: TextStyle(
                        fontSize: screenWidth * 0.037,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 4),
                    if (reward['activity_title'] != null &&
                        reward['activity_title'].toString().isNotEmpty) ...[
                      Text(
                        "From: ${reward['activity_title']}",
                        style: TextStyle(
                          fontSize: screenWidth * 0.03,
                          color: Colors.blue,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: 2),
                    ],
                    Row(
                      children: [
                        Icon(
                          reward['type'] == 'coins' || reward['type'] == 'points'
                              ? Icons.stars
                              : reward['type'] == 'voucher'
                                  ? Icons.card_giftcard
                                  : Icons.shopping_bag,
                          size: 16,
                          color: Colors.grey,
                        ),
                        SizedBox(width: 4),
                        Text(
                          reward['type'] == 'coins' || reward['type'] == 'points'
                              ? "${reward['reward_value'] ?? reward['cost_points'] ?? 0} ${reward['type'] == 'coins' ? 'Coins' : 'Points'}"
                              : reward['type'] == 'voucher'
                                  ? "₹${reward['voucher_value'] ?? 0} Voucher"
                                  : reward['product_name'] ?? 'Product',
                          style: TextStyle(
                            fontSize: screenWidth * 0.03,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isUnclaimed)
                ElevatedButton(
                  onPressed: () => _claimReward(reward),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Claim',
                    style: TextStyle(fontSize: screenWidth * 0.03),
                  ),
                )
              else
                Icon(Icons.check_circle, color: Colors.green, size: 24),
            ],
          ),
          if (isUnclaimed) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[800]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap "Claim" to add this reward to your wallet',
                      style: TextStyle(
                        fontSize: screenWidth * 0.028,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _claimReward(Map<String, dynamic> reward) async {
    final activityId = reward['activity_id'] as String?;
    if (activityId == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _claimService.claimReward(
        userId: user.uid,
        activityId: activityId,
      );

      Navigator.pop(context); // Close loading dialog

      if (result?['success'] == true) {
        // Refresh rewards
        Provider.of<RewardProvider>(context, listen: false).loadRewards();
        // Refresh wallet
        Provider.of<WalletProvider>(context, listen: false).fetchWalletAmount();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reward claimed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result?['error'] ?? 'Failed to claim reward'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error claiming reward: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Widget _buildMilestoneRewardCard(Map<String, dynamic> reward, double screenWidth, double screenHeight) {
    final milestoneTitle = reward['milestone_title'] as String? ?? 'Milestone';
    final month = reward['month'] as String? ?? '';
    final levelNumber = reward['level_number'] as int? ?? 0;
    final rewardAmount = reward['reward'] as int? ?? 0;
    final claimedAt = reward['claimed_at'] as Timestamp?;
    
    String claimedDate = '';
    if (claimedAt != null) {
      final date = claimedAt.toDate();
      claimedDate = DateFormat('MMM dd, yyyy').format(date);
    }

    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.02),
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.purple.shade200, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        color: Colors.purple.shade50,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.purple.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag, color: Colors.white, size: 16),
                Text(
                  'L$levelNumber',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestoneTitle,
                  style: TextStyle(
                    fontSize: screenWidth * 0.037,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$month - Level $levelNumber',
                  style: TextStyle(
                    fontSize: screenWidth * 0.03,
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (claimedDate.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    'Claimed: $claimedDate',
                    style: TextStyle(
                      fontSize: screenWidth * 0.028,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.stars, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  '+$rewardAmount',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.035,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      body: SafeArea(
        child: Consumer2<WalletProvider, RewardProvider>(
          builder: (context, walletProvider, rewardProvider, child) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenHeight * 0.01),
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

                  // Profile & Wallet Card
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
                                  Icon(Icons.stars,
                                      size: 18, color: Colors.orange),
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
                                  Text(
                                    _userRank != null ? '#$_userRank' : '#--',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.035,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    _rankTrendUp
                                        ? Icons.arrow_drop_up
                                        : Icons.arrow_drop_down,
                                    color:
                                        _rankTrendUp ? Colors.green : Colors.red,
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

                  // My Rewards with Tabs
                  Text(
                    "My Rewards",
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  // Tabs for Yet to Claim and Claimed
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTab == 0 ? Colors.orange : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                "Yet to Claim",
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedTab == 0 ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 1),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTab == 1 ? Colors.green : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                "Claimed",
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedTab == 1 ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  SizedBox(
                    width: double.infinity,
                    child: rewardProvider.isLoading
                        ? LoadingComponents.gridLoading(
                            screenWidth: screenWidth,
                            screenHeight: screenHeight,
                            crossAxisCount: 2,
                            itemCount: 4,
                          )
                        : _buildRewardsList(rewardProvider.rewards, screenWidth, screenHeight),
                  ),
                  SizedBox(height: screenHeight * 0.03),

                  // Milestone Rewards Section
                  if (_milestoneRewards.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.flag, color: Colors.purple, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Milestone Rewards",
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Text(
                      "Coins earned from completing milestone levels",
                      style: TextStyle(
                        fontSize: screenWidth * 0.03,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    _milestoneRewardsLoading
                        ? Center(child: CircularProgressIndicator())
                        : Column(
                            children: _milestoneRewards.map((reward) {
                              return _buildMilestoneRewardCard(reward, screenWidth, screenHeight);
                            }).toList(),
                          ),
                    SizedBox(height: screenHeight * 0.03),
                  ],

                  // Top Winners Today
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        child: Text("Invite",
                            style: TextStyle(fontSize: screenWidth * 0.035)),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    "Invite Friends to Earn More Freebies",
                    style:
                        TextStyle(fontSize: screenWidth * 0.03, color: Colors.grey),
                  ),
                  SizedBox(height: screenHeight * 0.02),

                  // Top Winners Avatars
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToRedemption,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: Icon(Icons.account_balance_wallet),
        label: Text(
          "Redeem Coins",
          style: TextStyle(
            fontSize: screenWidth * 0.04,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}