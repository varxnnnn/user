// ui/screens/polls_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/poll_provider.dart';
import '../../pages/explore_tabs/polls/poll_detail_page.dart'; // keep your existing detail page

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
            return const Center(child: CircularProgressIndicator());
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
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.orange,
                    child: Text(
                      (poll['sponsorName'] ?? 'S')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    poll['activityTitle'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(poll['rewardDescription'] ?? ''),
                  trailing: attempted
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 12),
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
                            final questions =
                                (poll['questions'] as List<dynamic>? ?? [])
                                    .map((q) => Map<String, dynamic>.from(q))
                                    .toList();

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PollDetailPage(
                                  userId: currentUser.uid,
                                  activityId: activityId,
                                  title: poll['activityTitle'] ?? '',
                                  description: poll['rewardDescription'] ?? '',
                                  sponsorName: poll['sponsorName'] ?? '',
                                  sponsorLogo: poll['sponsorLogo'] ?? '',
                                  pointsAwarded: pointsAwarded,
                                  rewardType: poll['rewardType'] ?? 'Points',
                                  questions: questions,
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
                          child: const Text("Participate"),
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
