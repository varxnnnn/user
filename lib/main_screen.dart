import 'package:flutter/material.dart';
import 'pages/explore_page.dart';
import 'ui/screens/milestone_page.dart';
import 'ui/screens/home_screen.dart';
import 'pages/freebies_page.dart';
// import 'pages/wallet_page.dart';
// import 'pages/profile_page.dart';

import 'package:flutter/services.dart';
import 'ui/screens/wallet_page.dart';
import 'ui/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    MilestonePage(),
    WalletScreen(),
    ExploreScreen(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // <-- Add SafeArea here
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.card_giftcard), label: "Milestone"),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: "Wallet"),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: "Explore"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
