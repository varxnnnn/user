// ui/screens/surveys_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/survey_provider.dart';
import '../../../pages/explore_tabs/survey/survey_detail_page.dart'; // keep your existing page
import '../components/loading_components.dart';

class SurveysScreen extends StatelessWidget {
  const SurveysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SurveyProvider>().loadSurveys();
    });

    return Scaffold(
      body: Consumer<SurveyProvider>(
        builder: (context, surveyProvider, child) {
          if (surveyProvider.isLoading) {
            return LoadingComponents.listScreenLoading(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
            );
          }

          if (surveyProvider.error != null) {
            return Center(child: Text('Error: ${surveyProvider.error}'));
          }

          if (surveyProvider.surveys.isEmpty) {
            return const Center(child: Text("No surveys available"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: surveyProvider.surveys.length,
            itemBuilder: (context, index) {
              final survey = surveyProvider.surveys[index];
              final activityId = survey['activityId'] as String;
              final completed = surveyProvider.isCompleted(activityId);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
<<<<<<< HEAD
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.orange,
                    child: Text(
                      (survey['sponsorName'] ?? 'S')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    survey['activityTitle'] ?? 'Untitled Survey',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(survey['rewardDescription'] ?? ''),
                  trailing: completed
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "Completed",
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () {
                            final questions = (survey['questions'] as List<dynamic>? ?? [])
                                .map((q) => Map<String, dynamic>.from(q))
                                .toList();

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SurveyDetailPage(
                                  userId: currentUser.uid,
                                  activityId: activityId,
                                  title: survey['activityTitle'] ?? '',
                                  description: survey['rewardDescription'] ?? '',
                                  sponsorName: survey['sponsorName'] ?? '',
                                  sponsorLogo: survey['sponsorLogo'] ?? '',
                                  rewardType: survey['rewardType'] ?? 'Points',
                                  rewardedItem: survey['rewardedItem'] ?? '',
                                  questions: questions,
                                  pointsAwarded: survey['rewardedItem'] ?? '',
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.orange,
                            backgroundImage: survey['sponsorProfilePic']?.toString().isNotEmpty == true ? NetworkImage(survey['sponsorProfilePic'] as String) : null,
                            child: survey['sponsorProfilePic']?.toString().isNotEmpty != true ? Text((survey['sponsorName'] ?? 'S')[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
                            onBackgroundImageError: (exception, stackTrace) {
                              debugPrint('Failed to load sponsor profile pic: $exception');
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(survey['activityTitle'] ?? 'Untitled Survey', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Row(children: [const Icon(Icons.business, size: 16, color: Colors.grey), const SizedBox(width: 4), Text(survey['sponsorName'] ?? '', style: const TextStyle(color: Colors.grey))])
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            completed
                                ? Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)), child: const Text('Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
                                : ElevatedButton(
                                    onPressed: () {
                                      final questions = (survey['questions'] as List<dynamic>? ?? []).map((q) => Map<String, dynamic>.from(q)).toList();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SurveyDetailPage(
                                            userId: currentUser.uid,
                                            activityId: activityId,
                                            title: survey['activityTitle'] ?? '',
                                            description: survey['rewardDescription'] ?? '',
                                            sponsorName: survey['sponsorName'] ?? '',
                                            sponsorProfilePic: survey['sponsorProfilePic'] ?? '',
                                            rewardType: survey['rewardType'] ?? 'Points',
                                            rewardedItem: survey['rewardedItem'] ?? '',
                                            questions: questions,
                                            pointsAwarded: survey['rewardedItem'] ?? '',
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                    child: const Text('Participate'),
                                  )
                          ])
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Reward details (simple)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Builder(builder: (_) {
                          final rTitle = survey['rewardTitle'] as String? ?? '';
                          final rType = (survey['rewardType'] ?? 'points').toString();
                          final rData = (survey['rewardData'] as Map<String, dynamic>?) ?? <String, dynamic>{};
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