// ui/screens/all_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/all_activities_provider.dart';
import '../../../pages/explore_tabs/polls/poll_detail_page.dart';
import '../../../pages/explore_tabs/quiz/quiz_detail_page.dart';
import '../../../pages/explore_tabs/survey/survey_detail_page.dart';

class AllPage extends StatelessWidget {
  const AllPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AllActivitiesProvider>().loadAllActivities();
    });

    return Scaffold(
      body: Consumer<AllActivitiesProvider>(
        builder: (context, provider, child) {
          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;

          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(child: Text('Error: ${provider.error}'));
          }

          final quickEarnList = provider.quickEarnList;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Featured Offer Banner (keep as-is)
                _buildFeaturedBanner(screenWidth),

                SizedBox(height: screenHeight * 0.03),

                // Quick Earn Section
                const Text(
                  "Quick Earn",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                ),
                SizedBox(height: screenHeight * 0.02),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: quickEarnList.length,
                  itemBuilder: (context, index) {
                    final item = quickEarnList[index];
                    final activityId = item['activityId'] as String;
                    final attempted = provider.isAttempted(activityId);

                    return _buildQuickEarnCard(
                      context,
                      item,
                      attempted,
                      currentUser.uid,
                      screenWidth,
                    );
                  },
                ),

                SizedBox(height: screenHeight * 0.03),

                // Featured Offers & Tech Challenge (keep as-is)
                _buildFeaturedAndTechSection(screenWidth, screenHeight),
                SizedBox(height: screenHeight * 0.05),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedBanner(double screenWidth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Earn Instant",
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Flipkart Voucher",
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "of Worth \$300",
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple[500],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Now Ranked #1",
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
          Container(
            width: screenWidth * 0.2,
            height: screenWidth * 0.2,
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[300]!),
            ),
            child: const Center(
              child: Text(
                "logo",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickEarnCard(
    BuildContext context,
    Map<String, dynamic> item,
    bool attempted,
    String userId,
    double screenWidth,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']!,
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['desc']!,
                  style: TextStyle(
                    fontSize: screenWidth * 0.03,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[500],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item['type']!,
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${item['points']} | ${item['time']}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!attempted)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange[500],
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => _navigateToDetail(context, item, userId),
                icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Done",
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToDetail(BuildContext context, Map<String, dynamic> item, String userId) {
    final rawType = item['rawType'] as String;
    final questions = (item['questions'] as List<dynamic>)
        .map((q) => Map<String, dynamic>.from(q))
        .toList();

    Widget page;
    switch (rawType) {
      case 'poll':
        page = PollDetailPage(
          userId: userId,
          activityId: item['activityId'],
          title: item['title'],
          description: item['desc'],
          sponsorName: item['sponsorName'],
          sponsorLogo: '',
          pointsAwarded: int.tryParse(item['points'].toString().split(' ')[0]) ?? 0,
          rewardType: 'Points',
          questions: questions,
        );
        break;
      case 'quiz':
        page = QuizDetailPage(
          userId: userId,
          activityId: item['activityId'],
          title: item['title'],
          description: item['desc'],
          sponsorName: item['sponsorName'],
          sponsorLogo: '',
          durationSeconds: 300,
          pointsAwarded: int.tryParse(item['points'].toString().split(' ')[0]) ?? 0,
          rewardType: 'Points',
          questions: questions,
          rewardedItem: item['points'],
        );
        break;
      case 'survey':
        page = SurveyDetailPage(
          userId: userId,
          activityId: item['activityId'],
          title: item['title'],
          description: item['desc'],
          sponsorName: item['sponsorName'],
          sponsorLogo: '',
          rewardType: 'Points',
          rewardedItem: item['points'],
          questions: questions,
          pointsAwarded: int.tryParse(item['points'].toString().split(' ')[0]) ?? 0,
        );
        break;
      default:
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildFeaturedAndTechSection(double screenWidth, double screenHeight) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Featured\nOffers",
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: screenWidth * 0.02,
                  mainAxisSpacing: screenWidth * 0.02,
                  childAspectRatio: 1.0,
                ),
                itemCount: 4,
                itemBuilder: (context, index) {
                  final labels = ["Gains", "Skin", "Voucher", "Electronics"];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Center(
                      child: Text(
                        labels[index],
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(width: screenWidth * 0.03),
        SizedBox(
          width: screenWidth * 0.45,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Tech\nKnowledge\nChallenge",
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              Text(
                "Test your tech knowledge",
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange[500],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Ongoing",
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              Text(
                "21 Questions",
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(
                  "Start Now",
                  style: TextStyle(fontSize: screenWidth * 0.035),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}