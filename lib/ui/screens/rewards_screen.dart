import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/rewards_provider.dart';
import 'package:giftardo/providers/luck_draw_win_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({Key? key}) : super(key: key);

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rewardsProvider = Provider.of<RewardsProvider>(context, listen: false);
      final luckDrawWinProvider = Provider.of<LuckDrawWinProvider>(context, listen: false);
      
      rewardsProvider.loadRewards();
      luckDrawWinProvider.loadWins();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rewards'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Rewards'),
            Tab(text: 'Luck Draw Wins'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Rewards Tab
          Consumer<RewardsProvider>(
            builder: (context, rewardsProvider, child) {
              if (rewardsProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (rewardsProvider.error != null) {
                return Center(child: Text('Error: ${rewardsProvider.error}'));
              }

              if (rewardsProvider.rewards.isEmpty) {
                return const Center(
                  child: Text(
                    'No rewards earned yet.\nComplete activities to earn rewards!',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rewardsProvider.rewards.length,
                itemBuilder: (context, index) {
                  final reward = rewardsProvider.rewards[index];
                  final timestamp = reward['timestamp'] as Timestamp?;
                  final formattedDate = timestamp != null
                      ? "${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}"
                      : 'N/A';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  reward['reward_title'] ?? 'Reward',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "Earned",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            reward['reward_description'] ?? '',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Display reward details based on type
                          Builder(
                            builder: (context) {
                              final rewardType = reward['reward_type'] as String? ?? 'points';
                              final rewardData = reward['reward_data'] as Map<String, dynamic>? ?? {};
                              
                              if (rewardType == 'coins') {
                                return Text(
                                  '${rewardData['amount'] ?? reward['reward_value'] ?? 0} Coins',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              } else if (rewardType == 'product') {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rewardData['name'] ?? 'Product Reward',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (rewardData['brand'] != null)
                                      Text(
                                        'Brand: ${rewardData['brand']}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (rewardData['category'] != null)
                                      Text(
                                        'Category: ${rewardData['category']}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                );
                              } else {
                                return Text(
                                  '${reward['reward_value'] ?? 0} Points',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Luck Draw Wins Tab
          Consumer<LuckDrawWinProvider>(
            builder: (context, luckDrawWinProvider, child) {
              if (luckDrawWinProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (luckDrawWinProvider.error != null) {
                return Center(child: Text('Error: ${luckDrawWinProvider.error}'));
              }

              if (luckDrawWinProvider.wins.isEmpty) {
                return const Center(
                  child: Text(
                    'No luck draw wins yet.\nParticipate in luck draw activities to win!',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: luckDrawWinProvider.wins.length,
                itemBuilder: (context, index) {
                  final win = luckDrawWinProvider.wins[index];
                  final awardedAt = win['awardedAt'] as Timestamp?;
                  final formattedDate = awardedAt != null
                      ? "${awardedAt.toDate().day}/${awardedAt.toDate().month}/${awardedAt.toDate().year}"
                      : 'N/A';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    color: Colors.purple.withOpacity(0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  win['activityTitle'] ?? 'Luck Draw Win',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "Winner!",
                                  style: TextStyle(
                                    color: Colors.purple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            win['rewardTitle'] ?? 'Reward',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            win['rewardDescription'] ?? '',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Display reward details based on type
                          Builder(
                            builder: (context) {
                              final rewardType = win['rewardType'] as String? ?? 'points';
                              final rewardData = win['rewardData'] as Map<String, dynamic>? ?? {};
                              
                              if (rewardType == 'coins') {
                                return Text(
                                  '${rewardData['amount'] ?? win['rewardValue'] ?? 0} Coins',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              } else if (rewardType == 'product') {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rewardData['name'] ?? 'Product Reward',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (rewardData['brand'] != null)
                                      Text(
                                        'Brand: ${rewardData['brand']}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (rewardData['category'] != null)
                                      Text(
                                        'Category: ${rewardData['category']}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                );
                              } else {
                                return Text(
                                  '${win['rewardValue'] ?? 0} Points',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                "Won on: $formattedDate",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}