import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/youtube_provider.dart';
import '../../pages/explore_tabs/youtube/youtube_detail_page.dart';
import '../components/loading_components.dart';

class YoutubeScreen extends StatelessWidget {
  const YoutubeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    // Load youtube activities once when screen builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<YoutubeProvider>().loadYoutubeActivities();
    });

    return Scaffold(
      body: Consumer<YoutubeProvider>(
        builder: (context, youtubeProvider, child) {
          if (youtubeProvider.isLoading) {
            return LoadingComponents.listScreenLoading(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
            );
          }

          if (youtubeProvider.error != null) {
            return Center(child: Text('Error: ${youtubeProvider.error}'));
          }

          if (youtubeProvider.activities.isEmpty) {
            return const Center(child: Text("No Advertise Video activities available"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: youtubeProvider.activities.length,
            itemBuilder: (context, index) {
              final activity = youtubeProvider.activities[index];
              final activityId = activity['activityId'] as String;
              final completed = youtubeProvider.isCompleted(activityId);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sponsor info row with action button on the right
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.orange,
                            backgroundImage: activity['sponsorProfilePic']?.isNotEmpty == true
                                ? NetworkImage(activity['sponsorProfilePic'] as String)
                                : null,
                            child: activity['sponsorProfilePic']?.isNotEmpty != true
                                ? Text(
                                    (activity['sponsorName'] ?? 'S')[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity['activityTitle'] ?? 'Untitled Advertise Video Activity',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.business, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      activity['sponsorName'] ?? 'Anonymous Sponsor',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${activity['timerDuration'] ?? 60} seconds",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Display reward distribution type
                                if (activity['rewardDistributionType'] != null) ...[
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: activity['rewardDistributionType'] == 'lucky_draw' 
                                              ? Colors.purple.withOpacity(0.2) 
                                              : Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          activity['rewardDistributionType'] == 'lucky_draw' 
                                              ? 'Lucky Draw' 
                                              : 'First Come First Serve',
                                          style: TextStyle(
                                            color: activity['rewardDistributionType'] == 'lucky_draw' 
                                                ? Colors.purple 
                                                : Colors.green,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (activity['isRewardsCompleted'] == true && activity['rewardDistributionType'] == 'first_come_first_serve') ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Rewards Completed',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ] else if (activity['rewardDistributionType'] == 'first_come_first_serve' && activity['remainingQuantity'] != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '${activity['remainingQuantity']} left',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            )
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Action button vertically aligned to top-right of the card
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              completed
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        "Completed",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : activity['isRewardsCompleted'] == true && activity['rewardDistributionType'] == 'first_come_first_serve'
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        "Rewards Completed",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => YoutubeDetailPage(
                                              userId: currentUser.uid,
                                              activityId: activityId,
                                              title: activity['activityTitle'] ?? '',
                                              description: activity['description'] ?? '',
                                              sponsorName: activity['sponsorName'] ?? '',
                                              sponsorLogo: activity['sponsorProfilePic'] ?? '',
                                              rewardType: activity['rewardType'] ?? 'Points',
                                              rewardedItem: activity['rewardedItem'] ?? 0,
                                              youtubeLink: activity['youtubeLink'] ?? '',
                                              timerDuration: activity['timerDuration'] ?? 60,
                                              rewardTitle: activity['rewardTitle'],
                                              rewardDescription: activity['rewardDescription'],
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Start'),
                                    ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Reward details
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.card_giftcard, color: Colors.orange),
                                SizedBox(width: 12),
                                Text(
                                  'Activity Reward',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Enhanced reward display
                            Builder(builder: (ctx) {
                              final rewardTitle = activity['rewardTitle'] as String? ?? '';
                              final rewardType = (activity['rewardType'] ?? 'points').toString().toLowerCase();
                              final rewardData = (activity['rewardData'] as Map<String, dynamic>?) ?? <String, dynamic>{};
                              final rewardedItem = activity['rewardedItem'] ?? 0;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (rewardTitle.isNotEmpty) ...[
                                    Text(
                                      rewardTitle,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Row(
                                    children: [
                                      Icon(
                                        rewardType == 'coins' 
                                          ? Icons.monetization_on
                                          : rewardType == 'voucher'
                                            ? Icons.card_giftcard
                                            : rewardType == 'product'
                                              ? Icons.shopping_bag
                                              : Icons.stars,
                                        size: 18,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (rewardType == 'coins')
                                              Text(
                                                '${rewardData['amount'] ?? rewardedItem ?? 0} Coins',
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                              )
                                            else if (rewardType == 'voucher')
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '₹${rewardData['value'] ?? rewardedItem ?? 0} ${rewardData['currency'] ?? 'INR'} Voucher',
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                                  ),
                                                  if (rewardData['description'] != null)
                                                    Text(
                                                      rewardData['description'] as String,
                                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                ],
                                              )
                                            else if (rewardType == 'product')
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    rewardData['name'] ?? 'Product Reward',
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                                  ),
                                                  if (rewardData['brand'] != null)
                                                    Text(
                                                      'Brand: ${rewardData['brand']}',
                                                      style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                                                    ),
                                                  if (rewardData['category'] != null)
                                                    Text(
                                                      'Category: ${rewardData['category']}',
                                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                                    ),
                                                  if (rewardData['price'] != null)
                                                    Text(
                                                      'Value: ₹${rewardData['price']}',
                                                      style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w600),
                                                    ),
                                                ],
                                              )
                                            else
                                              Text(
                                                '${rewardedItem ?? 0} Points',
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}