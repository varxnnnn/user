// lib/pages/milestone_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/milestone_provider.dart';
import 'package:giftardo/providers/wallet_provider.dart';
import 'leaderboard_screen.dart';

class MilestonePage extends StatefulWidget {
  const MilestonePage({super.key});

  @override
  State<MilestonePage> createState() => _MilestonePageState();
}

class _MilestonePageState extends State<MilestonePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MilestoneProvider>(context, listen: false).loadTasks();
      Provider.of<WalletProvider>(context, listen: false).fetchWalletAmount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer2<MilestoneProvider, WalletProvider>(
          builder: (context, milestoneProvider, walletProvider, child) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                          children: [
                            TextSpan(text: "BestThings"),
                            TextSpan(text: "Free", style: TextStyle(color: Colors.orange)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
  const Icon(Icons.monetization_on, color: Colors.orange),
  const SizedBox(width: 4),
  Text(
    "₹ ${walletProvider.walletAmount}",
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  ),
],
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) =>  LeaderboardPage()),
                      );
                    },
                    icon: const Icon(Icons.trending_up, color: Colors.white),
                    label: const Text("View Leaderboard", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Column(
                    children: [
                      const Text("Progress", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: milestoneProvider.progress,
                          backgroundColor: Colors.red.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: milestoneProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: milestoneProvider.tasks.length,
                          padding: const EdgeInsets.only(bottom: 16),
                          itemBuilder: (context, index) {
                            final task = milestoneProvider.tasks[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.shade300),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 30,
                                    width: 30,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange, width: 2),
                                      color: task["completed"] ? Colors.orange : Colors.transparent,
                                    ),
                                    child: task["completed"]
                                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                                        : const Icon(Icons.star_border, color: Colors.orange, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(task["title"], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        Text(task["subtitle"], style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                        Text("Earn ${task["points"]} points", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}