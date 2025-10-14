import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  Future<int> fetchWalletPoints() async {
    if (_uid == null) return 0;
    final doc = await _firestore.collection('users').doc(_uid).get();
    return doc.data()?['points'] ?? 0;
  }

  Future<List<Map<String, dynamic>>> fetchRewardCards() async {
    final snapshot = await _firestore
        .collection('tasks')
        .where('is_active', isEqualTo: true)
        .limit(3)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        "title": data['title'] ?? "Complete Task",
        "buttonText": "Start Now",
        "bgColor": Colors.orangeAccent, // or map from type
        "points": data['reward']['points'] ?? 50,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchVouchers() async {
    final snapshot = await _firestore
        .collection('sponsor_rewards')
        .where('status', isEqualTo: 'active')
        .limit(3)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        "title": data['title'] ?? "Reward",
        "image": "https://via.placeholder.com/120x200", // TODO: add image field later
        "cost": data['cost_points'] ?? 100,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchOngoingTasks() async {
    if (_uid == null) return [];
    final userTasks = await _firestore
        .collection('user_tasks')
        .where('user_id', isEqualTo: _uid)
        .where('status', isEqualTo: 'in_progress')
        .limit(3)
        .get();

    final tasks = <Map<String, dynamic>>[];
    for (var ut in userTasks.docs) {
      final taskRef = ut.data()['task_id'];
      final taskDoc = await _firestore.collection('tasks').doc(taskRef).get();
      if (taskDoc.exists) {
        final taskData = taskDoc.data()!;
        tasks.add({
          "title": taskData['title'],
          "points": "+${taskData['reward']['points'] ?? 0}",
        });
      }
    }
    return tasks;
  }

  Future<List<Map<String, dynamic>>> fetchTopWinners() async {
    final snapshot = await _firestore
        .collection('leaderboard')
        .orderBy('points', descending: true)
        .limit(3)
        .get();

    final winners = <Map<String, dynamic>>[];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      // Fetch user name from 'users' collection
      final userDoc = await _firestore.collection('users').doc(data['user_id']).get();
      winners.add({
        "name": userDoc.data()?['name'] ?? "User",
        "image": "https://via.placeholder.com/50", // TODO: add avatar later
        "points": data['points'],
      });
    }
    return winners;
  }
}

class Colors {
  static const int orangeAccent = 0xFFFFA500;
}