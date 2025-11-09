import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/rewards_display_provider.dart';
import 'package:giftardo/providers/auth_provider.dart';

class RewardsDisplayWidget extends StatefulWidget {
  const RewardsDisplayWidget({super.key});

  @override
  State<RewardsDisplayWidget> createState() => _RewardsDisplayWidgetState();
}

class _RewardsDisplayWidgetState extends State<RewardsDisplayWidget> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final rewardsProvider = Provider.of<RewardsDisplayProvider>(context, listen: false);
      if (auth.user != null && rewardsProvider.lastLoadedUserId != auth.user!.uid) {
        // Load once after first build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          rewardsProvider.loadUserRewards(auth.user!.uid);
        });
      }
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RewardsDisplayProvider, AuthProvider>(
      builder: (context, rewardsProvider, authProvider, child) {
        if (authProvider.user == null) return const SizedBox.shrink();

        if (rewardsProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (rewardsProvider.error != null) {
          return Center(
            child: Text(
              'Error loading rewards: ${rewardsProvider.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rewards Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade100, Colors.orange.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.card_giftcard, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Rewards Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildRewardStat(
                        'Total Rewards',
                        '${rewardsProvider.totalRewardsEarned}',
                        Icons.stars,
                        Colors.orange,
                      ),
                      _buildRewardStat(
                        'Activities Completed',
                        '${rewardsProvider.totalActivitiesCompleted}',
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Recent Rewards
            Text(
              'Recent Rewards',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),

            if (rewardsProvider.earnedRewards.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.card_giftcard_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'No rewards earned yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete activities to earn rewards!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rewardsProvider.recentRewards.length,
                itemBuilder: (context, index) {
                  final reward = rewardsProvider.recentRewards[index];
                  return _buildRewardItem(reward, index);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildRewardStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildRewardItem(Map<String, dynamic> reward, int index) {
    final rewardValue = reward['reward_value'] as int? ?? 0;
    final rewardCode = reward['reward_code'] as String? ?? '';
    final rewardType = reward['reward_type'] as String? ?? 'points';
    final rewardData = reward['reward_data'] as Map<String, dynamic>? ?? {};
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.card_giftcard,
              color: Colors.orange.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward['reward_title'] ?? 'Activity Reward',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                // Display reward details based on type
                if (rewardType == 'coins')
                  Text(
                    '${rewardData['amount'] ?? rewardValue} Coins',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  )
                else if (rewardType == 'product')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rewardData['name'] ?? 'Product Reward',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      if (rewardData['brand'] != null)
                        Text(
                          'Brand: ${rewardData['brand']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (rewardData['category'] != null)
                        Text(
                          'Category: ${rewardData['category']}',
                          style:  TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  )
                else if (rewardType == 'voucher')
                  Text(
                    '${rewardData['value'] ?? rewardValue} ${rewardData['currency'] ?? 'INR'} Voucher',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  )
                else
                  Text(
                    '$rewardValue Points',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
