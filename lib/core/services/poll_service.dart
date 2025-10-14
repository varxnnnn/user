// service/poll_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PollService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all polls: sponsor_activities where type == 'poll'
  Future<List<Map<String, dynamic>>> fetchPolls() async {
    final query = _firestore
        .collection('sponsor_activities')
        .where('type', isEqualTo: 'poll')
        .where('status', isEqualTo: 'active');

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'activityId': doc.id,
        'activityTitle': data['title'] ?? '',
        'rewardDescription': data['description'] ?? '',
        'sponsorName': data['sponsor_name'] ?? 'Sponsor',
        'sponsorLogo': data['sponsor_logo'],
        'rewardedItem': data['reward']?['points'] ?? 0,
        'rewardType': 'Points',
        'questions': (data['questions'] as List<dynamic>?) ?? [],
      };
    }).toList();
  }

  // Check if user has attempted this poll
  Future<bool> hasUserAttempted(String userId, String activityId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('poll_attempts')
        .doc(activityId)
        .get();

    return doc.exists;
  }
}