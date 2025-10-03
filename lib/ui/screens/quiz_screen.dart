// ui/screens/quizzes_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/quiz_provider.dart';
import '../../../pages/explore_tabs/quiz/quiz_detail_page.dart'; // keep your existing page

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizProvider>().loadQuizzes();
    });

    return Scaffold(
      body: Consumer<QuizProvider>(
        builder: (context, quizProvider, child) {
          if (quizProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
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
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.orange,
                    child: Text(
                      (quiz['activityTitle'] ?? 'A')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    quiz['activityTitle'] ?? 'Untitled Quiz',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(quiz['rewardDescription'] ?? ''),
                  trailing: attempted
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                  sponsorLogo: '', // as in your original
                                  durationSeconds: quiz['durationSeconds'] ?? 0,
                                  pointsAwarded: quiz['rewardedItem'] ?? 0,
                                  rewardType: quiz['rewardType'] ?? 'Points',
                                  questions: (quiz['questions'] as List<dynamic>)
                                      .map((q) => Map<String, dynamic>.from(q))
                                      .toList(),
                                  rewardedItem: quiz['rewardedItem'] ?? 0,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Start"),
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