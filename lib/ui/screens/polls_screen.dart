// ui/screens/polls_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/poll_provider.dart';
import '../../pages/explore_tabs/polls/poll_detail_page.dart'; // keep your existing detail page
import '../components/loading_components.dart';

class PollsScreen extends StatelessWidget {
  const PollsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    // Trigger data load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PollProvider>().loadPolls();
    });

    return Scaffold(
      body: Consumer<PollProvider>(
        builder: (context, pollProvider, child) {
          if (pollProvider.isLoading) {
            return LoadingComponents.listScreenLoading(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
            );
          }

          if (pollProvider.error != null) {
            return Center(child: Text('Error: ${pollProvider.error}'));
          }

          if (pollProvider.polls.isEmpty) {
            return const Center(child: Text('No polls available'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pollProvider.polls.length,
            itemBuilder: (context, index) {
              final poll = pollProvider.polls[index];
              final pointsAwarded =
                  int.tryParse(poll['rewardedItem']?.toString() ?? '0') ?? 0;
              final activityId = poll['activityId'] as String;
              final attempted = pollProvider.isAttempted(activityId);

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
                      // Top row: avatar, title/sponsor, action
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.orange,
                            backgroundImage: poll['sponsorProfilePic']?.toString().isNotEmpty == true
                                ? NetworkImage(poll['sponsorProfilePic'] as String)
                                : null,
                            child: poll['sponsorProfilePic']?.toString().isNotEmpty != true
                                ? Text((poll['sponsorName'] ?? 'S')[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                                : null,
                            onBackgroundImageError: (exception, stackTrace) {
                              debugPrint('Failed to load sponsor profile pic: $exception');
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(poll['activityTitle'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Row(children: [const Icon(Icons.business, size: 16, color: Colors.grey), const SizedBox(width: 4), Text(poll['sponsorName'] ?? '', style: const TextStyle(color: Colors.grey))]),
                                const SizedBox(height: 4),
                                // Display reward distribution type
                                if (poll['rewardDistributionType'] != null) ...[
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: poll['rewardDistributionType'] == 'lucky_draw' 
                                              ? Colors.purple.withOpacity(0.2) 
                                              : Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          poll['rewardDistributionType'] == 'lucky_draw' 
                                              ? 'Lucky Draw' 
                                              : 'First Come First Serve',
                                          style: TextStyle(
                                            color: poll['rewardDistributionType'] == 'lucky_draw' 
                                                ? Colors.purple 
                                                : Colors.green,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (poll['isRewardsCompleted'] == true && poll['rewardDistributionType'] == 'first_come_first_serve') ...[
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
                                      ] else if (poll['rewardDistributionType'] == 'first_come_first_serve' && poll['remainingQuantity'] != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '${poll['remainingQuantity']} left',
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
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              attempted
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                                      child: const Text('Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    )
                                  : poll['isRewardsCompleted'] == true && poll['rewardDistributionType'] == 'first_come_first_serve'
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                                      child: const Text('Rewards Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                    )
                                  : ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PollDetailPage(
                                              userId: currentUser.uid,
                                              activityId: activityId,
                                              title: poll['activityTitle'] ?? '',
                                              description: poll['rewardDescription'] ?? '',
                                              sponsorName: poll['sponsorName'] ?? '',
                                              sponsorProfilePic: poll['sponsorProfilePic'] ?? '',
                                              pointsAwarded: pointsAwarded,
                                              rewardType: poll['rewardType'] ?? 'Points',
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                      child: const Text('Participate'),
                                    )
                            ],
                          )
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Enhanced reward details
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Builder(builder: (_) {
                          final rewardTitle = poll['rewardTitle'] as String? ?? '';
                          final rewardType = (poll['rewardType'] ?? 'points').toString().toLowerCase();
                          final rewardData = (poll['rewardData'] as Map<String, dynamic>?) ?? <String, dynamic>{};
                          final rewardedItem = poll['rewardedItem'] ?? 0;

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
