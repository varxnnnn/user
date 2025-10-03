import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _leaders = [];
  int _walletAmount = 250; // fallback
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 1. Fetch wallet (points) for current user
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _walletAmount = userDoc.data()?['points'] ?? 250;
          });
        }
      }

      // 2. Fetch leaderboard
      final leaderboardSnapshot = await _firestore
          .collection('leaderboard')
          .orderBy('points', descending: true)
          .limit(10)
          .get();

      final List<Map<String, dynamic>> leaders = [];
      for (var doc in leaderboardSnapshot.docs) {
        final data = doc.data();
        final userId = data['user_id'];

        // Fetch user name
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final name = userDoc.exists ? userDoc.data() != null ? userDoc.data()!['name'] ?? "User" : "User" : "User";

        leaders.add({
          "rank": "#${leaders.length + 1}",
          "name": name,
          "points": data['points'] ?? 0,
          "avatar": "https://via.placeholder.com/150", // Replace later with real avatar
          "trend": "up", // Simplified; enhance with history if needed
          "isCurrentUser": user?.uid == userId,
        });
      }

      // 3. Add dummy data if less than 4 users (to preserve UI)
      final dummyAvatars = [
        "https://i.imgur.com/9KZuFfT.png",
        "https://i.imgur.com/LpQ7vLd.png",
        "https://i.imgur.com/YeWcVYq.png",
        "https://i.imgur.com/9KZuFfT.png",
      ];
      final dummyNames = ["Jack Nicklson", "Joe Addamson", "Alley Sholay", "Rolex Roar"];
      final dummyPoints = [25006, 29096, 20753, 19053];

      while (leaders.length < 4) {
        leaders.add({
          "rank": "#${leaders.length + 1}",
          "name": dummyNames[leaders.length % dummyNames.length],
          "points": dummyPoints[leaders.length % dummyPoints.length],
          "avatar": dummyAvatars[leaders.length % dummyAvatars.length],
          "trend": leaders.length.isEven ? "up" : "down",
          "isCurrentUser": false,
        });
      }

      setState(() {
        _leaders = leaders;
        _loading = false;
      });
    } catch (e) {
      // On error, use full dummy data
      _loadDummyData();
    }
  }

  void _loadDummyData() {
    setState(() {
      _leaders = [
        {"rank": "#1", "name": "Joe Addamson", "points": 29096, "avatar": "https://i.imgur.com/LpQ7vLd.png", "trend": "up", "isCurrentUser": false},
        {"rank": "#2", "name": "Jack Nicklson", "points": 25006, "avatar": "https://i.imgur.com/9KZuFfT.png", "trend": "up", "isCurrentUser": false},
        {"rank": "#3", "name": "Alley Sholay", "points": 20753, "avatar": "https://i.imgur.com/YeWcVYq.png", "trend": "down", "isCurrentUser": false},
        {"rank": "#4", "name": "Rolex Roar", "points": 19053, "avatar": "https://i.imgur.com/YeWcVYq.png", "trend": "up", "isCurrentUser": false},
      ];
      _loading = false;
    });
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
            Text("BestThings", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
            Text("Free", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, size: 20, color: Colors.orange),
                const SizedBox(width: 4),
                Text("₹ $_walletAmount", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top 3
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildTopRankCard(
                            rank: _leaders.length > 1 ? _leaders[1]["rank"] : "#2",
                            name: _leaders.length > 1 ? _leaders[1]["name"] : "Jack Nicklson",
                            points: _leaders.length > 1 ? _leaders[1]["points"].toString() : "25,006",
                            avatar: _leaders.length > 1 ? _leaders[1]["avatar"] : "https://i.imgur.com/9KZuFfT.png",
                            color: Colors.orangeAccent,
                            heightFactor: 1.75,
                          ),
                          const SizedBox(width: 12),
                          _buildTopRankCard(
                            rank: _leaders.isNotEmpty ? _leaders[0]["rank"] : "#1",
                            name: _leaders.isNotEmpty ? _leaders[0]["name"] : "Joe Addamson",
                            points: _leaders.isNotEmpty ? _leaders[0]["points"].toString() : "29,096",
                            avatar: _leaders.isNotEmpty ? _leaders[0]["avatar"] : "https://i.imgur.com/LpQ7vLd.png",
                            color: Colors.greenAccent,
                            heightFactor: 2.0,
                          ),
                          const SizedBox(width: 12),
                          _buildTopRankCard(
                            rank: _leaders.length > 2 ? _leaders[2]["rank"] : "#3",
                            name: _leaders.length > 2 ? _leaders[2]["name"] : "Alley Sholay",
                            points: _leaders.length > 2 ? _leaders[2]["points"].toString() : "20,753",
                            avatar: _leaders.length > 2 ? _leaders[2]["avatar"] : "https://i.imgur.com/YeWcVYq.png",
                            color: Colors.purpleAccent,
                            heightFactor: 1.5,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Rest of the list
                    ...List.generate(
                      _leaders.length > 3 ? _leaders.length - 3 : 1,
                      (index) {
                        final i = index + 3;
                        final leader = i < _leaders.length
                            ? _leaders[i]
                            : {
                                "rank": "#${i + 1}",
                                "name": "User ${i + 1}",
                                "points": 10000 - i * 500,
                                "avatar": "https://via.placeholder.com/150",
                                "trend": "up",
                                "isCurrentUser": false,
                              };
                        return Column(
                          children: [
                            _buildRankItem(
                              rank: leader["rank"],
                              name: leader["name"],
                              points: leader["points"].toString(),
                              avatar: leader["avatar"],
                              trend: leader["trend"],
                              bgColor: leader["isCurrentUser"] ? Colors.orangeAccent : Colors.white,
                              borderColor: leader["isCurrentUser"]
                                  ? const Color.fromARGB(255, 255, 145, 2)
                                  : const Color.fromARGB(255, 0, 0, 0).withOpacity(0.2),
                            ),
                            const SizedBox(height: 10),
                          ],
                        );
                      },
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
    required String avatar,
    required Color color,
    double heightFactor = 1.0,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: NetworkImage(avatar.trim()),
              fit: BoxFit.cover,
            ),
            border: Border.all(color: Colors.grey[300]!, width: 2),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 90,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
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
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
    required String avatar,
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
          Text(rank, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: NetworkImage(avatar.trim()),
                fit: BoxFit.cover,
              ),
              border: Border.all(color: Colors.grey[300]!, width: 2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text("₹ $points", style: const TextStyle(fontSize: 10, color: Colors.white)),
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