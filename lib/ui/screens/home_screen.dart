// lib/pages/home_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/pages/explore_page.dart';
import 'package:giftardo/pages/voucher_detail_page.dart';
import 'package:giftardo/providers/wallet_provider.dart';
import 'package:giftardo/providers/milestone_provider.dart';
import '../components/loading_components.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 NEW
import 'package:cached_network_image/cached_network_image.dart'; // 👈 NEW
import 'all_activities_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _vouchers = [];
  bool _vouchersLoading = true;

  // 👇 Store winner user IDs, not avatar URLs
  List<Map<String, dynamic>> _topWinners = [];
  bool _winnersLoading = true;

  final FirebaseAuth _auth = FirebaseAuth.instance; // 👈 NEW

  String? _getProfileImageUrl(String? userId) {
    if (userId == null) return null;
    final path = 'profiles/$userId.jpg';
    // Encode the entire path so '/' becomes '%2F'
    final encodedPath = Uri.encodeComponent(path);
    return 'https://firebasestorage.googleapis.com/v0/b/giftardo-43381.firebasestorage.app/o/$encodedPath?alt=media';
  }

  Future<void> fetchVouchers() async {
    setState(() {
      _vouchersLoading = true;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sponsor_rewards')
          .get();
      _vouchers = snapshot.docs
          .where((doc) => (doc.data()['metadata']?['voucher']) != null)
          .map((doc) {
        final data = doc.data();
        final voucher = data['metadata']['voucher'];
        return {
          "title": data['title'] ?? '',
          "description": data['description'] ?? '',
          "value": voucher['value'] ?? 0,
          "currency": voucher['currency'] ?? '',
          "available_quantity": data['available_quantity'] ?? 0,
          "status": data['status'] ?? '',
          "sponsor_id": data['sponsor_id'] ?? '',
          "color": Colors.orange,
        };
      })
          .toList();
    } catch (e) {
      _vouchers = [];
    }
    setState(() {
      _vouchersLoading = false;
    });
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchVouchers();
  }

  final PageController _rewardController = PageController(viewportFraction: 0.9);
  int _currentRewardPage = 0;
  Timer? _timer;

  final PageController _voucherController = PageController(viewportFraction: 0.6);
  int _currentVoucherPage = 0;
  Timer? _voucherTimer;

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
      Provider.of<MilestoneProvider>(context, listen: false).loadTasks();
      _fetchTopWinners();
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

    _voucherTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_voucherController.hasClients) {
        _currentVoucherPage = (_currentVoucherPage + 1) % 3;
        _voucherController.animateToPage(
          _currentVoucherPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _voucherTimer?.cancel();
    _rewardController.dispose();
    _voucherController.dispose();
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
            final vouchers = _vouchers;
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

                    // Reward Cards
                    SizedBox(
                      height: 140,
                      child: PageView.builder(
                        controller: _rewardController,
                        itemCount: rewardCards.length,
                        itemBuilder: (context, index) {
                          final card = rewardCards[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: card["bgColor"] as Color,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    card["title"] as String,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: card["bgColor"] as Color,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      card["buttonText"] as String,
                                      style: TextStyle(
                                        color: card["bgColor"] as Color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Earn Vouchers Section
                    Column(
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
                        _vouchersLoading
                            ? const Center(child: CircularProgressIndicator())
                            : SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: vouchers.length,
                            itemBuilder: (context, index) {
                              final voucher = vouchers[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ExploreScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 150,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                      BorderRadius.circular(12),
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(
                                            0.3,
                                          ),
                                          spreadRadius: 2,
                                          blurRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 100,
                                          decoration: BoxDecoration(
                                            color:
                                            voucher["color"] as Color,
                                            borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(
                                                12,
                                              ),
                                            ),
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment:
                                              MainAxisAlignment
                                                  .center,
                                              children: [
                                                Icon(
                                                  Icons.local_offer,
                                                  color: Colors.white,
                                                  size: 40,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  "${voucher["value"]} ${voucher["currency"]}",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                    FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                voucher["title"] ??
                                                    "Untitled Voucher",
                                                style: const TextStyle(
                                                  fontWeight:
                                                  FontWeight.bold,
                                                  fontSize: 14,
                                                  overflow: TextOverflow
                                                      .ellipsis,
                                                ),
                                                maxLines: 1,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.inventory,
                                                    size: 16,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Avail: ${voucher["available_quantity"]}",
                                                    style:
                                                    const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                      Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            VoucherDetailPage(
                                                              voucher:
                                                              voucher,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                    Colors.orange,
                                                    foregroundColor:
                                                    Colors.black,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                        8,
                                                      ),
                                                    ),
                                                    padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    "Get Now",
                                                    style: TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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
                            children: milestoneProvider.tasks.map((task) {
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