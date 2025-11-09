import 'package:flutter/material.dart';
import '../create_rewards_tab.dart';
import '../manage_rewards_tab.dart';


class SponsorRewardsPage extends StatefulWidget {
  const SponsorRewardsPage({super.key});

  @override
  _SponsorRewardsPageState createState() => _SponsorRewardsPageState();
}

class _SponsorRewardsPageState extends State<SponsorRewardsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rewards"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Create Rewards"),
            Tab(text: "Manage Rewards"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          CreateRewardsTab(),
          ManageRewardsTab(),
        ],
      ),
    );
  }
}
