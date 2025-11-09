import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/quiz_provider.dart';
import '../../../pages/explore_tabs/quiz/quiz_detail_page.dart';
import '../components/loading_components.dart';

class QuizzesScreen extends StatelessWidget {
  const QuizzesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    // Load quizzes once when screen builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizProvider>().loadQuizzes();
    });

    return Scaffold(
      body: Consumer<QuizProvider>(
        builder: (context, quizProvider, child) {
          if (quizProvider.isLoading) {
            return LoadingComponents.listScreenLoading(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
            );
          }

          if (quizProvider.error != null) {
            return Center(child: Text('Error: ${quizProvider.error}'));
          }

          if (quizProvider.quizzes.isEmpty) {
            return const Center(child: Text("No quizzes available"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: quizProvider.quizzes.length,
            itemBuilder: (context, index) {
              final quiz = quizProvider.quizzes[index];
              final activityId = quiz['activityId'] as String;
              final attempted = quizProvider.isAttempted(activityId);
              
              // Check if activity is within participation period
              final startDate = quiz['startDate'] as DateTime?;
              final endDate = quiz['endDate'] as DateTime?;
              final isWithinPeriod = quiz['isWithinParticipationPeriod'] as bool? ?? true;
              final rewardDistributionType = quiz['rewardDistributionType'] as String? ?? 'first_come_first_serve';

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
                      // 🧩 Sponsor info row with action button on the right
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.orange,
                            backgroundImage: quiz['sponsorProfilePic']?.isNotEmpty == true
                                ? NetworkImage(quiz['sponsorProfilePic'] as String)
                                : null,
                            child: quiz['sponsorProfilePic']?.isNotEmpty != true
                                ? Text(
                                    (quiz['sponsorName'] ?? 'S')[0].toUpperCase(),
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
                                  quiz['activityTitle'] ?? 'Untitled Quiz',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.business, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      quiz['sponsorName'] ?? 'Anonymous Sponsor',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                // Display dates and distribution type
                                if (startDate != null && endDate != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${startDate.day}/${startDate.month}/${startDate.year} - ${endDate.day}/${endDate.month}/${endDate.year}",
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (rewardDistributionType != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: rewardDistributionType == 'lucky_draw' 
                                              ? Colors.purple.withOpacity(0.2) 
                                              : Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          rewardDistributionType == 'lucky_draw' 
                                              ? 'Lucky Draw' 
                                              : 'First Come First Serve',
                                          style: TextStyle(
                                            color: rewardDistributionType == 'lucky_draw' 
                                                ? Colors.purple 
                                                : Colors.green,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (quiz['isRewardsCompleted'] == true && rewardDistributionType == 'first_come_first_serve') ...[
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
                                      ] else if (rewardDistributionType == 'first_come_first_serve' && quiz['remainingQuantity'] != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '${quiz['remainingQuantity']} left',
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
                          // Action button vertically aligned to top-right of the card
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              attempted
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
                                  : quiz['isRewardsCompleted'] == true && rewardDistributionType == 'first_come_first_serve'
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
                                  : !isWithinPeriod
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        "Outside Period",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => QuizDetailPage(
                                              userId: currentUser.uid,
                                              activityId: activityId,
                                              title: quiz['activityTitle'] ?? '',
                                              description: quiz['rewardDescription'] ?? '',
                                              sponsorName: quiz['sponsorName'] ?? '',
                                              sponsorLogo: quiz['sponsorProfilePic'] ?? '',
                                              pointsAwarded: quiz['rewardedItem'] ?? 0,
                                              rewardType: quiz['rewardType'] ?? 'Points',
                                              questions: [],
                                              rewardedItem: quiz['rewardedItem'] ?? 0,
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

                      // 🎁 Reward details
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.card_giftcard, color: Colors.orange),
                                const SizedBox(width: 12),
                                Text(
                                  'Quiz Reward',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Enhanced reward display: show title, type and metadata
                            Builder(builder: (ctx) {
                              final rewardTitle = quiz['rewardTitle'] as String? ?? '';
                              final rewardType = (quiz['rewardType'] ?? 'points').toString().toLowerCase();
                              final rewardData = (quiz['rewardData'] as Map<String, dynamic>?) ?? <String, dynamic>{};
                              final rewardedItem = quiz['rewardedItem'] ?? 0;

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
                                          ? Icons.stars
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
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.people_outline, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  'Sponsored by ${quiz['sponsorName']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      const SizedBox.shrink(),
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