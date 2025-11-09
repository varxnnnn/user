import 'package:flutter/material.dart';
import '../create_ads_tab.dart';
import '../manage_ads_tab.dart';

class AdsDashboard extends StatelessWidget {
  const AdsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
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
                Tab(text: "Create Ad", icon: Icon(Icons.add_circle_outline)),
                Tab(text: "Manage Ads", icon: Icon(Icons.list_alt)),
              ],
            ),
          ),
          // Tab Content
          const Expanded(
            child: TabBarView(
              children: [
                CreateAdsTab(),
                ManageAdsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

