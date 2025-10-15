// lib/pages/leaderboard_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 👈 NEW
import '../components/loading_components.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _topLeaders = [];
  Map<String, dynamic>? _currentUserData;
  int _currentUserRank = 0;
  bool _loading = true;

  // 👇 Helper to build Firebase Storage image URL
  String _getProfileImageUrl(String userId) {
    final path = 'profiles/$userId.jpg';
    final encodedPath = Uri.encodeComponent(path); // 👈 Correct encoding
    return 'https://firebasestorage.googleapis.com/v0/b/giftardo-43381.firebasestorage.app/o/$encodedPath?alt=media'; // 👈 No extra spaces!
  }

  // 👇 Build avatar with caching and fallback
  Widget _buildCachedAvatar(String userId, String name) {
    final imageUrl = _getProfileImageUrl(userId);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: 60,
        height: 60,
        placeholder: (context, url) => _buildInitials(initial, 60),
        errorWidget: (context, url, error) => _buildInitials(initial, 60),
      ),
    );
  }

  Widget _buildInitials(String initial, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.orange,
        border: Border.all(color: Colors.grey[300]!, width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _loading = false;
        });
        return;
      }

      // Fetch current user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        setState(() {
          _loading = false;
        });
        return;
      }

      final currentUserPoints = userDoc.data()?['points'] ?? 0;
      _currentUserData = {
        "uid": user.uid,
        "name": userDoc.data()?['name'] ?? "You",
        "points": currentUserPoints,
        // 👇 No longer uses 'avatar' field
      };

      // Fetch top 10 users by points
      final snapshot = await _firestore
          .collection('users')
          .orderBy('points', descending: true)
          .limit(10)
          .get();

      final List<Map<String, dynamic>> leaders = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        leaders.add({
          "uid": doc.id,
          "name": data['name'] ?? "User",
          "points": data['points'] ?? 0,
          "isCurrentUser": doc.id == user.uid,
        });
      }

      // Determine current user's rank
      bool userInTop10 = false;
      for (int i = 0; i < leaders.length; i++) {
        if (leaders[i]["uid"] == user.uid) {
          _currentUserRank = i + 1;
          userInTop10 = true;
          break;
        }
      }

      if (!userInTop10) {
        final countSnapshot = await _firestore
            .collection('users')
            .where('points', isGreaterThan: currentUserPoints)
            .count()
            .get();
        _currentUserRank = (countSnapshot.count! + 1);
      }

      setState(() {
        _topLeaders = leaders;
        _loading = false;
      });
    } catch (e) {
      if (kDebugMode) print("Error loading leaderboard: $e");
      setState(() {
        _topLeaders = [];
        _currentUserData = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Text(
              "Giftardo",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              "Free",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.monetization_on,
                  size: 20,
                  color: Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  "₹ ${_currentUserData?['points'] ?? 0}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? LoadingComponents.leaderboardScreenLoading(
        MediaQuery.of(context).size.width,
        MediaQuery.of(context).size.height,
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top 3 Cards
              if (_topLeaders.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_topLeaders.length > 1)
                        _buildTopRankCard(
                          rank: "#2",
                          name: _topLeaders[1]["name"],
                          points: _topLeaders[1]["points"].toString(),
                          userId: _topLeaders[1]["uid"],
                          color: Colors.orangeAccent,
                          heightFactor: 1.75,
                        ),
                      const SizedBox(width: 12),
                      _buildTopRankCard(
                        rank: "#1",
                        name: _topLeaders[0]["name"],
                        points: _topLeaders[0]["points"].toString(),
                        userId: _topLeaders[0]["uid"],
                        color: Colors.greenAccent,
                        heightFactor: 2.0,
                      ),
                      const SizedBox(width: 12),
                      if (_topLeaders.length > 2)
                        _buildTopRankCard(
                          rank: "#3",
                          name: _topLeaders[2]["name"],
                          points: _topLeaders[2]["points"].toString(),
                          userId: _topLeaders[2]["uid"],
                          color: Colors.purpleAccent,
                          heightFactor: 1.5,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Rest of Top 10 (positions 4–10)
              ...List.generate(
                _topLeaders.length > 3 ? _topLeaders.length - 3 : 0,
                    (index) {
                  final i = index + 3;
                  final leader = _topLeaders[i];
                  return Column(
                    children: [
                      _buildRankItem(
                        rank: "#${i + 1}",
                        name: leader["name"],
                        points: leader["points"].toString(),
                        userId: leader["uid"],
                        trend: "up",
                        bgColor: leader["isCurrentUser"]
                            ? Colors.orangeAccent
                            : Colors.white,
                        borderColor: leader["isCurrentUser"]
                            ? const Color.fromARGB(255, 255, 145, 2)
                            : const Color.fromARGB(
                          255,
                          0,
                          0,
                          0,
                        ).withOpacity(0.2),
                      ),
                      const SizedBox(height: 10),
                    ],
                  );
                },
              ),

              // Show current user if not in top 10
              if (_currentUserData != null &&
                  !_topLeaders.any(
                        (u) => u["uid"] == _currentUserData!["uid"],
                  ))
                Column(
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      "Your Position",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildRankItem(
                      rank: "#$_currentUserRank",
                      name: _currentUserData!["name"],
                      points: _currentUserData!["points"].toString(),
                      userId: _currentUserData!["uid"],
                      trend: "up",
                      bgColor: Colors.orangeAccent,
                      borderColor: const Color.fromARGB(255, 255, 145, 2),
                    ),
                  ],
                ),

              if (!_loading && _topLeaders.isEmpty)
                const Center(
                  child: Text("No leaderboard data available."),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopRankCard({
    required String rank,
    required String name,
    required String points,
    required String userId,
    required Color color,
    double heightFactor = 1.0,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildCachedAvatar(userId, name),
        const SizedBox(height: 8),
        SizedBox(
          width: 90,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "₹ $points",
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 80,
          height: 80 * heightFactor,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              rank,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankItem({
    required String rank,
    required String name,
    required String points,
    required String userId,
    required String trend,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            rank,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 12),
          _buildCachedAvatar(userId, name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "₹ $points",
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            trend == "up" ? Icons.arrow_upward : Icons.arrow_downward,
            color: trend == "up" ? Colors.green : Colors.red,
            size: 16,
          ),
        ],
      ),
    );
  }
}