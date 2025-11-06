// lib/pages/home_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/pages/explore_page.dart';
import 'package:giftardo/providers/wallet_provider.dart';
import 'package:giftardo/providers/milestone_provider.dart';
import 'package:giftardo/providers/all_activities_provider.dart';
import '../components/loading_components.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 NEW
import 'package:cached_network_image/cached_network_image.dart'; // 👈 NEW
import 'all_activities_screen.dart';
import '../../../pages/explore_tabs/polls/poll_detail_page.dart';
import '../../../pages/explore_tabs/quiz/quiz_detail_page.dart';
import '../../../pages/explore_tabs/survey/survey_detail_page.dart';
import 'package:intl/intl.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 👇 Store winner user IDs, not avatar URLs
  List<Map<String, dynamic>> _topWinners = [];
  bool _winnersLoading = true;

  final FirebaseAuth _auth = FirebaseAuth.instance; // 👈 NEW

  // 👇 Store ads from Firestore
  List<Map<String, dynamic>> _ads = [];
  bool _adsLoading = true;

  String? _getProfileImageUrl(String? userId) {
    if (userId == null) return null;
    final path = 'profiles/$userId.jpg';
    // Encode the entire path so '/' becomes '%2F'
    final encodedPath = Uri.encodeComponent(path);
    return 'https://firebasestorage.googleapis.com/v0/b/giftardo-43381.firebasestorage.app/o/$encodedPath?alt=media';
  }

  // 👇 Fetch top winners by user ID (not avatar field)
  Future<void> _fetchTopWinners() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('points', descending: true)
          .limit(3)
          .get();
      final List<Map<String, dynamic>> winners = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] ?? 'User';
        final userId = doc.id; // 👈 Use document ID as user ID
        winners.add({'name': name, 'userId': userId});
      }
      setState(() {
        _topWinners = winners;
        _winnersLoading = false;
      });
    } catch (e) {
      setState(() {
        _topWinners = [];
        _winnersLoading = false;
      });
    }
  }

  // 👇 Fetch ads from Firestore
  Future<void> _fetchAds() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('ads')
          .where('status', isEqualTo: 'active')
          .get();
      final List<Map<String, dynamic>> ads = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = data['created_at'] as Timestamp?;
        ads.add({
          'id': doc.id,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'image_url': data['image_url'] ?? '',
          'link': data['link'],
          'created_at': createdAt,
        });
      }
      // Sort by created_at descending (newest first)
      ads.sort((a, b) {
        final aCreated = a['created_at'] as Timestamp?;
        final bCreated = b['created_at'] as Timestamp?;
        if (aCreated == null && bCreated == null) return 0;
        if (aCreated == null) return 1;
        if (bCreated == null) return -1;
        return bCreated.compareTo(aCreated);
      });
      setState(() {
        _ads = ads;
        _adsLoading = false;
        // Update timer to use ads count
        if (_ads.isNotEmpty && _adsController.hasClients) {
          _currentAdPage = _currentAdPage % _ads.length;
        }
      });
    } catch (e) {
      setState(() {
        _ads = [];
        _adsLoading = false;
      });
    }
  }

  final PageController _rewardController = PageController(viewportFraction: 0.9);
  final PageController _adsController = PageController(viewportFraction: 0.9);
  int _currentRewardPage = 0;
  int _currentAdPage = 0;
  Timer? _timer;
  Timer? _adsTimer;

  final categories = [
    {"name": "Quizzes", "icon": Icons.quiz, "color": Colors.blue},
    {"name": "Watch Ads", "icon": Icons.play_circle, "color": Colors.green},
    {"name": "Surveys", "icon": Icons.assignment, "color": Colors.purple},
    {"name": "Offers", "icon": Icons.local_offer, "color": Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WalletProvider>(context, listen: false).fetchWalletAmount();
      Provider.of<MilestoneProvider>(context, listen: false).loadMilestones();
      Provider.of<AllActivitiesProvider>(context, listen: false).loadAllActivities();
      _fetchTopWinners();
      _fetchAds();
    });

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_rewardController.hasClients) {
        _currentRewardPage = (_currentRewardPage + 1) % 3;
        _rewardController.animateToPage(
          _currentRewardPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });

    // Auto-scroll ads timer
    _adsTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_adsController.hasClients && _ads.isNotEmpty) {
        _currentAdPage = (_currentAdPage + 1) % _ads.length;
        _adsController.animateToPage(
          _currentAdPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _adsTimer?.cancel();
    _rewardController.dispose();
    _adsController.dispose();
    super.dispose();
  }

  Widget _buildAvatarFromUrl(String? imageUrl, String fallbackText) {
    if (imageUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: 50,
          height: 50,
          placeholder: (context, url) => _buildInitials(fallbackText),
          errorWidget: (context, url, error) => _buildInitials(fallbackText),
        ),
      );
    }
    return _buildInitials(fallbackText);
  }

  Widget _buildInitials(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.orange,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    final currentUserId = currentUser?.uid;
    final currentUserEmail = currentUser?.email ?? "User";
    final currentUserInitial = currentUserEmail.isNotEmpty
        ? currentUserEmail[0].toUpperCase()
        : 'U';

    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        return Consumer<MilestoneProvider>(
          builder: (context, milestoneProvider, child) {
            final rewardCards = [
              {
                "title": "Start Earning Now",
                "buttonText": "Get Started",
                "bgColor": Colors.orangeAccent,
              },
              {
                "title": "Special Offer",
                "buttonText": "Check Now",
                "bgColor": Colors.blueAccent,
              },
              {
                "title": "Limited Time Deal",
                "buttonText": "Grab Now",
                "bgColor": Colors.greenAccent,
              },
            ];

            return Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar — 👇 Updated Avatar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            currentUserId != null
                                ? _buildAvatarFromUrl(
                              _getProfileImageUrl(currentUserId),
                              currentUserInitial,
                            )
                                : const CircleAvatar(
                              radius: 25,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Giftardo",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Free",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.notifications_outlined),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.orange,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.monetization_on,
                                    color: Colors.orange,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    walletProvider.walletAmount.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Categories
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ExploreScreen(),
                                  ),
                                );
                              },
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: cat["color"] as Color,
                                    child: Icon(
                                      cat["icon"] as IconData,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    cat["name"] as String,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Ads Section (Auto-scrolling)
                    SizedBox(
                      height: 180,
                      child: _adsLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _ads.isEmpty
                              ? Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.orange.shade200,
                                        Colors.orange.shade400,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.video_camera_back,
                                          size: 50,
                                          color: Colors.white,
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          "Coming Soon",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          "Stay tuned for exciting offers!",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : PageView.builder(
                                  controller: _adsController,
                                  itemCount: _ads.length,
                                  itemBuilder: (context, index) {
                                    final ad = _ads[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: GestureDetector(
                                        onTap: () {
                                          if (ad['link'] != null && ad['link'].toString().isNotEmpty) {
                                            // You can add URL launcher here if needed
                                          }
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                // Ad Image
                                                CachedNetworkImage(
                                                  imageUrl: ad['image_url'] ?? '',
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) => Container(
                                                    color: Colors.grey[300],
                                                    child: const Center(
                                                      child: CircularProgressIndicator(),
                                                    ),
                                                  ),
                                                  errorWidget: (context, url, error) => Container(
                                                    color: Colors.grey[300],
                                                    child: const Icon(
                                                      Icons.error,
                                                      size: 50,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                                // Gradient overlay for text readability
                                                Positioned(
                                                  bottom: 0,
                                                  left: 0,
                                                  right: 0,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment.bottomCenter,
                                                        end: Alignment.topCenter,
                                                        colors: [
                                                          Colors.black.withOpacity(0.8),
                                                          Colors.black.withOpacity(0.4),
                                                          Colors.transparent,
                                                        ],
                                                      ),
                                                    ),
                                                    padding: const EdgeInsets.all(16),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          ad['title'] ?? '',
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          ad['description'] ?? '',
                                                          style: TextStyle(
                                                            color: Colors.white.withOpacity(0.9),
                                                            fontSize: 12,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                    const SizedBox(height: 20),

                    // Earn Vouchers Section (using Quick Earn style)
                    Consumer<AllActivitiesProvider>(
                      builder: (context, allActivitiesProvider, child) {
                        final quickEarnList = allActivitiesProvider.quickEarnList;
                        final screenWidth = MediaQuery.of(context).size.width;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  "Earn Vouchers",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "View All",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            allActivitiesProvider.isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : Column(
                                    children: quickEarnList
                                        .where((item) => !allActivitiesProvider.isAttempted(item['activityId'] as String))
                                        .toList()
                                        .asMap()
                                        .entries
                                        .map((entry) => _AnimatedQuickEarnCard(
                                              item: entry.value,
                                              attempted: false,
                                              userId: currentUserId ?? '',
                                              screenWidth: screenWidth,
                                              delay: Duration(milliseconds: 100 * entry.key),
                                            ))
                                        .toList(),
                                  ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Ongoing Tasks
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              "Ongoing Tasks",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              "View All",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (milestoneProvider.isLoading)
                          LoadingComponents.homeScreenLoading(
                            MediaQuery.of(context).size.width,
                            MediaQuery.of(context).size.height,
                          )
                        else
                          Column(
                            children: milestoneProvider.levels.map((task) {
                              final pointsText = "+${task['points']}";
                              final isCompleted = task['completed'] == true;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(45),
                                    border: Border.all(
                                      color: Colors.orange,
                                      width: 2,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 25,
                                        backgroundColor: Colors.orange
                                            .withOpacity(0.2),
                                        child: Icon(
                                          isCompleted
                                              ? Icons.check
                                              : Icons.task,
                                          color: isCompleted
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              task['title'] ?? "Complete Task",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              isCompleted
                                                  ? "Completed"
                                                  : "Daily Challenge",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isCompleted
                                                    ? Colors.green
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.monetization_on,
                                            color: Colors.orange,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            pointsText,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.more_vert),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Explore Section
                    Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.orange[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          "Explore More Features",
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Top Winners Today — 👇 Updated with real images from Storage
                    const Text(
                      "Top Winners Today",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _winnersLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _topWinners.length,
                        itemBuilder: (context, index) {
                          final winner = _topWinners[index];
                          final name = winner['name'] as String;
                          final userId = winner['userId'] as String;
                          final imageUrl = _getProfileImageUrl(userId);
                          final initial = name.isNotEmpty
                              ? name[0].toUpperCase()
                              : '?';

                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Column(
                              children: [
                                _buildAvatarFromUrl(imageUrl, initial),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// 🔥 Animated Quick Earn Card (same as in all_activities_screen.dart)
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