// lib/pages/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/pages/explore_page.dart';
import 'package:giftardo/providers/wallet_provider.dart';
import 'package:giftardo/providers/milestone_provider.dart'; // ✅ Added import
import '../components/loading_components.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _rewardController = PageController(viewportFraction: 0.9);
  int _currentRewardPage = 0;
  Timer? _timer;

  final PageController _voucherController = PageController(viewportFraction: 0.6);
  int _currentVoucherPage = 0;
  Timer? _voucherTimer;

  // ✅ ONLY categories remain as dummy (navigation)
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
      // Fetch wallet
      Provider.of<WalletProvider>(context, listen: false).fetchWalletAmount();
      // ✅ Fetch tasks using MilestoneProvider
      Provider.of<MilestoneProvider>(context, listen: false).loadTasks();
    });

    // Auto-scroll rewards
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

    // Auto-scroll vouchers
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

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        return Consumer<MilestoneProvider>(
          builder: (context, milestoneProvider, child) {
            // Keep dummy data ONLY for UI structure (not fetched from DB)
            final vouchers = [
              {"title": "Voucher 1", "color": Colors.blue},
              {"title": "Voucher 2", "color": Colors.green},
              {"title": "Voucher 3", "color": Colors.purple},
            ];

            final winners = [
              {"name": "Alex", "initial": "A"},
              {"name": "John", "initial": "J"},
              {"name": "Lara", "initial": "L"},
            ];

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
                    // Top Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 25,
                              backgroundImage: NetworkImage("https://via.placeholder.com/150      "),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Giftardo",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.orange, width: 2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.monetization_on, color: Colors.orange, size: 18),
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
                            )
                          ],
                        )
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Categories (only dummy kept as requested)
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
                                Widget targetPage;
                                switch (cat["name"]) {
                                  case "Quizzes":
                                    targetPage = const ExploreScreen();
                                    break;
                                  case "Surveys":
                                    targetPage = const ExploreScreen();
                                    break;
                                  case "Watch Ads":
                                  case "Offers":
                                    targetPage = const ExploreScreen();
                                    break;
                                  default:
                                    targetPage = const ExploreScreen();
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => targetPage),
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
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Reward Cards (dummy UI only)
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

                    // Earn Vouchers Section (dummy UI only)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text("Earn Vouchers", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text("View All", style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold))
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: vouchers.length,
                            itemBuilder: (context, index) {
                              final voucher = vouchers[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 120,
                                      height: 160,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.3),
                                            spreadRadius: 2,
                                            blurRadius: 5,
                                          )
                                        ],
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: voucher["color"] as Color,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.local_offer,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: 100,
                                      height: 30,
                                      child: ElevatedButton(
                                        onPressed: () {},
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: const Text(
                                          "Get Now",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ✅ REPLACED: Ongoing Tasks Section with real data
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text("Ongoing Tasks", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text("View All", style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
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
                                    border: Border.all(color: Colors.orange, width: 2),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 25,
                                        backgroundColor: Colors.orange.withOpacity(0.2),
                                        child: Icon(
                                          isCompleted ? Icons.check : Icons.task,
                                          color: isCompleted ? Colors.green : Colors.orange,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              task['title'] ?? "Complete Task",
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              isCompleted ? "Completed" : "Daily Challenge",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isCompleted ? Colors.green : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.monetization_on, color: Colors.orange, size: 18),
                                          const SizedBox(width: 4),
                                          Text(
                                            pointsText,
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
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

                    // Top Winners Today (dummy UI only)
                    const Text("Top Winners Today", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: winners.length,
                        itemBuilder: (context, index) {
                          final winner = winners[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.orange,
                              child: Text(
                                winner["initial"]!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
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