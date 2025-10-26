import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/wallet_provider.dart';
import 'package:giftardo/pages/explore_tabs/ads_page.dart';
import 'package:giftardo/ui/screens/polls_screen.dart';
import 'package:giftardo/ui/screens/quiz_screen.dart';
import 'package:giftardo/ui/screens/survey_screen.dart';
import 'package:giftardo/ui/screens/all_activities_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = ['All', 'Polls', 'Quizzes', 'Surveys', 'Ads'];

  final List<Widget> _pages = const [
    AllPage(),
    PollsScreen(),
    QuizzesScreen(),
    SurveysScreen(),
    AdsPage(),
  ];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fetch wallet amount when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WalletProvider>(context, listen: false).fetchWalletAmount();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                SizedBox(height: screenHeight * 0.02),

                // 🔥 Header with balance
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(width: 25),
                    Text(
                      "Giftardo",
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 3),
                    
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.withOpacity(0.2), blurRadius: 4),
                        ],
                      ),
                      padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on,
                              size: 18, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            "₹ ${walletProvider.walletAmount}", // ✅ Dynamic wallet amount
                            style:
                            const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                  ],
                ),

                SizedBox(height: screenHeight * 0.02),

                // 🔥 Custom Tabs Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _tabs.map((tab) {
                      int index = _tabs.indexOf(tab);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTab = index;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: _selectedTab == index ? Colors.orange : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            tab,
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              fontWeight: _selectedTab == index
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: _selectedTab == index ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                SizedBox(height: screenHeight * 0.015),

                // 🔥 Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                  margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: "Search",
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                          onSubmitted: (value) {
                            print("Searching for: $value");
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                        onPressed: _clearSearch,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: screenHeight * 0.015),

                // 🔥 Show page based on selected tab
                Expanded(
                  child: _pages[_selectedTab],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}