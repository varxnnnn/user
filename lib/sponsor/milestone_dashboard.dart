import 'package:flutter/material.dart';
import 'create_milestone_tab.dart';
import 'manage_milestone_tab.dart';
import 'milestone_statistics_tab.dart';

class MilestoneDashboard extends StatelessWidget {
  const MilestoneDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Tab Bar
          Container(
            color: Theme.of(context).primaryColor,
            child: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'Create Milestone', icon: Icon(Icons.add_circle_outline)),
                Tab(text: 'Manage Milestones', icon: Icon(Icons.list_alt)),
                Tab(text: 'Statistics', icon: Icon(Icons.analytics)),
              ],
            ),
          ),
          // Tab Content
          const Expanded(
            child: TabBarView(
              children: [
                CreateMilestoneTab(),
                ManageMilestoneTab(),
                MilestoneStatisticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

