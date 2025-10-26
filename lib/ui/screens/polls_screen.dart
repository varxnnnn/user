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
<<<<<<< HEAD
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
        // ✅ No 'questions' needed — it loads from Firestore now
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
=======
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
                                Row(children: [const Icon(Icons.business, size: 16, color: Colors.grey), const SizedBox(width: 4), Text(poll['sponsorName'] ?? '', style: const TextStyle(color: Colors.grey))])
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

                      // Reward details (simple: title, type, metadata)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Builder(builder: (_) {
                          final rTitle = poll['rewardTitle'] as String? ?? '';
                          final rType = (poll['rewardType'] ?? 'points').toString();
                          final rData = (poll['rewardData'] as Map<String, dynamic>?) ?? <String, dynamic>{};
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(rTitle.isNotEmpty ? rTitle : 'Reward', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text('Type: ${rType[0].toUpperCase()}${rType.substring(1)}', style: const TextStyle(color: Colors.grey)),
                            if (rData.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              const Text('Details:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                              const SizedBox(height: 4),
                              ...rData.entries.map((e) => Text('${e.key}: ${e.value}', style: const TextStyle(color: Colors.grey, fontSize: 13))).toList()
                            ]
                          ]);
                        }),
                      ),
                    ],
                  ),
>>>>>>> f9e1824 (newly_updated_4)
                ),
              );
            },
          );
        },
      ),
    );
  }
}
