import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/rewards_display_provider.dart';
import 'package:giftardo/providers/auth_provider.dart';

class RewardsDisplayWidget extends StatelessWidget {
  const RewardsDisplayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<RewardsDisplayProvider, AuthProvider>(
      builder: (context, rewardsProvider, authProvider, child) {
        if (authProvider.user == null) return const SizedBox.shrink();

        return FutureBuilder<void>(
          future: rewardsProvider.loadUserRewards(authProvider.user!.uid),
          builder: (context, snapshot) {
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
                  'Activity Reward',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                if (rewardCode.isNotEmpty)
                  Text(
                    'Code: $rewardCode',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+$rewardValue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade600,
                ),
              ),
              Text(
                'points',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
