// service/quiz_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchQuizzes() async {
    final query = _firestore
        .collection('sponsor_activities')
        .where('type', isEqualTo: 'quiz')
        .where('status', isEqualTo: 'active');

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'activityId': doc.id,
        'activityTitle': data['title'] ?? 'Untitled Quiz',
        'rewardDescription': data['description'] ?? '',
        'sponsorName': data['sponsor_name'] ?? 'Sponsor',
        'durationSeconds': data['duration_seconds'] ?? 0,
        'rewardedItem': data['reward']?['points'] ?? 0,
        'rewardType': 'Points',
        'questions': (data['questions'] as List<dynamic>?) ?? [],
      };
    }).toList();
  }

  Future<bool> hasUserAttempted(String userId, String activityId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('quiz_attempts')
        .doc(activityId)
        .get();

    return doc.exists;
  }
}