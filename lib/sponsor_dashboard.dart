import 'package:admin/sponsor/rewards_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login_page.dart';
import 'sponsor/create_activity_page.dart';
import 'sponsor/users_page.dart';
import 'sponsor/profile_page.dart';
import 'sponsor/milestone_dashboard.dart';
import 'sponsor/monthly_claim_management_page.dart';

class SponsorDashboard extends StatefulWidget {
  const SponsorDashboard({super.key});

  @override
  _SponsorDashboardState createState() => _SponsorDashboardState();
}

class _SponsorDashboardState extends State<SponsorDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    ActivityDashboard(),
    SponsorRewardsPage(),
    UsersPage(),
    MilestoneDashboard(),
    MonthlyClaimManagementPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic titles based on selected tab
    final List<String> titles = [
      'Activity Dashboard',
      'Rewards Management',
      'User Management',
      'Milestone Dashboard',
      'Monthly Lucky Draw',
      'Profile',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.create), label: 'Activity'),
          BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Rewards'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.flag), label: 'Milestone'),
          BottomNavigationBarItem(icon: Icon(Icons.celebration), label: 'Monthly'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}