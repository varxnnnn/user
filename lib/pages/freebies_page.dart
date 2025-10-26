import 'package:flutter/material.dart';
// import 'MilestonePage.dart';
import 'package:giftardo/ui/screens/milestone_page.dart';
import 'package:giftardo/ui/screens/leaderboard_screen.dart';

class FreebiesPage extends StatelessWidget {
  const FreebiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Two tabs
      child: Column(
        children: [
          // Top TabBar
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Colors.orangeAccent,
              unselectedLabelColor: Colors.black,
              indicatorColor: Colors.orange,
              tabs: [
                Tab(text: "Milestone"),
                Tab(text: "Leaderboard"),
              ],
            ),
          ),
          // TabBarView
          Expanded(
            child: TabBarView(
              children: [
                MilestonePage(),
                LeaderboardPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
