// service/survey_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SurveyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchSurveys() async {
    final query = _firestore
        .collection('sponsor_activities')
        .where('type', isEqualTo: 'survey')
        .where('status', isEqualTo: 'active');

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'activityId': doc.id,
        'activityTitle': data['title'] ?? 'Untitled Survey',
        'rewardDescription': data['description'] ?? '',
        'sponsorName': data['sponsor_name'] ?? 'Sponsor',
        'sponsorLogo': data['sponsor_logo'],
        'rewardedItem': data['reward']?['points'] ?? 0,
        'rewardType': 'Points',
        'questions': (data['questions'] as List<dynamic>?) ?? [],
      };
    }).toList();
  }

  Future<bool> hasUserCompleted(String userId, String activityId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('survey_attempts')
        .doc(activityId)
        .get();

    return doc.exists;
  }
}