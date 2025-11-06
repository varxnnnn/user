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
                            // Simple reward: show title, type and metadata
                            Builder(builder: (ctx) {
                              final rewardTitle = quiz['rewardTitle'] as String? ?? '';
                              final rewardType = (quiz['rewardType'] ?? 'points').toString();
                              final rewardData = (quiz['rewardData'] as Map<String, dynamic>?) ?? <String, dynamic>{};

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rewardTitle.isNotEmpty ? rewardTitle : 'Reward',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Type: ${rewardType[0].toUpperCase()}${rewardType.substring(1)}', style: const TextStyle(color: Colors.grey)),
                                  if (rewardData.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    const Text('Details:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    ...rewardData.entries.map((e) => Text('${e.key}: ${e.value}', style: const TextStyle(color: Colors.grey, fontSize: 13))).toList(),
                                  ]
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
