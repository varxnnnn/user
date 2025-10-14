import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    final snapshot = await _firestore
        .collection('leaderboard')
        .orderBy('points', descending: true)
        .limit(10)
        .get();

    final List<Map<String, dynamic>> leaders = [];
    for (var doc in snapshot.docs) {
      final data = doc.data(); // skip if data is null

      final userId = data['user_id'] as String?; // nullable

      // Fetch user name
      String name = "User";
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        name = userDoc.data()?['name'] ?? "User";
      }

      // Determine trend (simplified - you can enhance with history)
      final trend = leaders.isEmpty ? "up" : "down";

      leaders.add({
        "rank": "#${leaders.length + 1}",
        "name": name,
        "points": data['points'] ?? 0,
        "avatar": "https://via.placeholder.com/150", // Replace with real avatar later
        "trend": trend,
        "isCurrentUser": false, // Set true if userId == current user
      });
    }
    return leaders;
  }
}
