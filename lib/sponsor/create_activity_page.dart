import 'package:flutter/material.dart';
import 'activites/create_activity_page.dart';
import 'activites/manage_activity_tab.dart';


class ActivityDashboard extends StatelessWidget {
  const ActivityDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Activities"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Create Activity"),
              Tab(text: "Manage Activities"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            CreateActivityPage(),
            const ManageActivityTab(),
          ],
        ),
      ),
    );
  }
}
