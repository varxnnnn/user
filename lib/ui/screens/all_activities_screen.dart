// ui/screens/all_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/all_activities_provider.dart';
import '../../../pages/explore_tabs/polls/poll_detail_page.dart';
import '../../../pages/explore_tabs/quiz/quiz_detail_page.dart';
import '../../../pages/explore_tabs/survey/survey_detail_page.dart';
import '../components/monthly_claim_button.dart';

class AllPage extends StatefulWidget {
  const AllPage({super.key});

  @override
  State<AllPage> createState() => _AllPageState();
}

class _AllPageState extends State<AllPage> with TickerProviderStateMixin {
  late AnimationController _screenController;
  late Animation<double> _screenOpacity;
  late Animation<Offset> _screenSlide;

  @override
  void initState() {
    super.initState();

    _screenController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _screenOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _screenController, curve: Curves.easeOutCubic),
    );

    _screenSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _screenController, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        context.read<AllActivitiesProvider>().loadAllActivities();
      }
      _screenController.forward();
    });
  }

  @override
  void dispose() {
    _screenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    return Scaffold(
      body: FadeTransition(
        opacity: _screenOpacity,
        child: SlideTransition(
          position: _screenSlide,
          child: Consumer<AllActivitiesProvider>(
            builder: (context, provider, child) {
              final screenWidth = MediaQuery.of(context).size.width;
              final screenHeight = MediaQuery.of(context).size.height;

              if (provider.isLoading) {
                return _buildShimmerLoading(screenWidth, screenHeight);
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
                    // Featured Offer Banner
                    _AnimatedFeaturedBanner(screenWidth),

                    SizedBox(height: screenHeight * 0.03),

                    // Monthly Claim Section (Separate from activities)
                    const Text(
                      "Monthly Lucky Draw",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    Container(
                      padding: EdgeInsets.all(screenWidth * 0.03),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade50, Colors.purple.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.celebration, color: Colors.purple.shade700, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Claim Your Monthly Entry",
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.045,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Complete any activity and claim your entry for this month's lucky draw!",
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Colors.purple.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          MonthlyClaimButton(
                            userId: currentUser.uid,
                            activityId: 'monthly_claim',
                            activityType: 'monthly_draw',
                            activityTitle: 'Monthly Lucky Draw Entry',
                            hasCompletedActivity: quickEarnList.any(
                              (item) => provider.isAttempted(item['activityId'] as String),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.03),

                    // Quick Earn Section
                    const Text(
                      "Quick Earn",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                    ),
                    SizedBox(height: screenHeight * 0.02),

                    quickEarnList.isEmpty || 
                    quickEarnList.where((item) => !provider.isAttempted(item['activityId'] as String)).isEmpty
                        ? _buildEmptyQuickEarnCard(screenWidth)
                        : Column(
                            children: quickEarnList
                                .where((item) => !provider.isAttempted(item['activityId'] as String))
                                .toList()
                                .asMap()
                                .entries
                                .map((entry) => _AnimatedQuickEarnCard(
                                      item: entry.value,
                                      attempted: false,
                                      userId: currentUser.uid,
                                      screenWidth: screenWidth,
                                      delay: Duration(milliseconds: 100 * entry.key),
                                    ))
                                .toList(),
                          ),

                    SizedBox(height: screenHeight * 0.03),

                    // Featured Offers & Tech Challenge
                    _buildFeaturedAndTechSection(screenWidth, screenHeight),
                    SizedBox(height: screenHeight * 0.05),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(double screenWidth, double screenHeight) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: double.infinity,
              height: screenHeight * 0.15,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.03),
          const Text("Quick Earn", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
          SizedBox(height: screenHeight * 0.02),
          ...List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            );
          }),
          SizedBox(height: screenHeight * 0.03),
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: screenHeight * 0.3,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyQuickEarnCard(double screenWidth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 56,
            color: Colors.orange.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Activities Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Currently no quick earn activities available.\nPlease wait patiently, new activities will be added soon!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

}

// 🔥 Animated Banner
class _AnimatedFeaturedBanner extends StatefulWidget {
  final double screenWidth;
  const _AnimatedFeaturedBanner(this.screenWidth);

  @override
  State<_AnimatedFeaturedBanner> createState() => _AnimatedFeaturedBannerState();
}

class _AnimatedFeaturedBannerState extends State<_AnimatedFeaturedBanner>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: _buildFeaturedBanner(widget.screenWidth),
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
}

// 🔥 Animated Quick Earn Card (FIXED: uses TickerProviderStateMixin)
class _AnimatedQuickEarnCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool attempted;
  final String userId;
  final double screenWidth;
  final Duration delay;

  const _AnimatedQuickEarnCard({
    required this.item,
    required this.attempted,
    required this.userId,
    required this.screenWidth,
    required this.delay,
  });

  @override
  State<_AnimatedQuickEarnCard> createState() => _AnimatedQuickEarnCardState();
}

class _AnimatedQuickEarnCardState extends State<_AnimatedQuickEarnCard>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _offset = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: _buildQuickEarnCard(
          context,
          widget.item,
          widget.attempted,
          widget.userId,
          widget.screenWidth,
        ),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 4),
                    // Display reward distribution type
                    if (item['rewardDistributionType'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item['rewardDistributionType'] == 'lucky_draw' 
                              ? Colors.purple[500] 
                              : Colors.green[500],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item['rewardDistributionType'] == 'lucky_draw' 
                              ? 'Lucky Draw' 
                              : 'First Come First Serve',
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
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
          pointsAwarded: int.tryParse(item['points'].toString().split(' ')[0]) ?? 0,
          rewardType: 'Points', sponsorProfilePic: item['sponsorProfilePic'] ?? '',
          // questions: questions,
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
          pointsAwarded: int.tryParse(item['points'].toString().split(' ')[0]) ?? 0,
          rewardType: 'Points',
          questions: [], // Empty list since we fetch from Firestore
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
          sponsorProfilePic: item['sponsorProfilePic'] ?? '',
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
}

// 🔹 Static section (no animation needed)
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