import 'package:flutter/material.dart';
import 'create_ads_tab.dart';

class AdsDashboard extends StatelessWidget {
  const AdsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Ads Management"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Create Ad"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CreateAdsTab(),
          ],
        ),
      ),
    );
  }
}