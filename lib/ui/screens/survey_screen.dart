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
                                Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [const Icon(Icons.business, size: 16, color: Colors.grey), const SizedBox(width: 4), Text(survey['sponsorName'] ?? '', style: const TextStyle(color: Colors.grey))]),
                                const SizedBox(height: 4),
                                // Display reward distribution type
                                if (survey['rewardDistributionType'] != null) ...[
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: survey['rewardDistributionType'] == 'lucky_draw' 
                                              ? Colors.purple.withOpacity(0.2) 
                                              : Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          survey['rewardDistributionType'] == 'lucky_draw' 
                                              ? 'Lucky Draw' 
                                              : 'First Come First Serve',
                                          style: TextStyle(
                                            color: survey['rewardDistributionType'] == 'lucky_draw' 
                                                ? Colors.purple 
                                                : Colors.green,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (survey['isRewardsCompleted'] == true && survey['rewardDistributionType'] == 'first_come_first_serve') ...[
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
                                      ] else if (survey['rewardDistributionType'] == 'first_come_first_serve' && survey['remainingQuantity'] != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '${survey['remainingQuantity']} left',
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
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            completed
                                ? Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)), child: const Text('Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
                                : survey['isRewardsCompleted'] == true && survey['rewardDistributionType'] == 'first_come_first_serve'
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                                    child: const Text('Rewards Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)))
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

                      // Enhanced reward details
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Builder(builder: (_) {
                          final rTitle = survey['rewardTitle'] as String? ?? '';
                          final rType = (survey['rewardType'] ?? 'points').toString().toLowerCase();
                          final rData = (survey['rewardData'] as Map<String, dynamic>?) ?? <String, dynamic>{};
                          final rewardedItem = survey['rewardedItem'] ?? 0;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (rTitle.isNotEmpty) ...[
                                Text(
                                  rTitle,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Row(
                                children: [
                                  Icon(
                                    rType == 'coins' 
                                      ? Icons.stars
                                      : rType == 'voucher'
                                        ? Icons.card_giftcard
                                        : rType == 'product'
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
                                        if (rType == 'coins')
                                          Text(
                                            '${rData['amount'] ?? rewardedItem ?? 0} Coins',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                          )
                                        else if (rType == 'voucher')
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '₹${rData['value'] ?? rewardedItem ?? 0} ${rData['currency'] ?? 'INR'} Voucher',
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                              ),
                                              if (rData['description'] != null)
                                                Text(
                                                  rData['description'] as String,
                                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                          )
                                        else if (rType == 'product')
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                rData['name'] ?? 'Product Reward',
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                              ),
                                              if (rData['brand'] != null)
                                                Text(
                                                  'Brand: ${rData['brand']}',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                                                ),
                                              if (rData['category'] != null)
                                                Text(
                                                  'Category: ${rData['category']}',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                                ),
                                              if (rData['price'] != null)
                                                Text(
                                                  'Value: ₹${rData['price']}',
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