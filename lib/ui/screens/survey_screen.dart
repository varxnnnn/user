// ui/screens/surveys_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/survey_provider.dart';
import '../../../pages/explore_tabs/survey/survey_detail_page.dart'; // keep your existing page

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
            return const Center(child: CircularProgressIndicator());
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}