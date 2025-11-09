// service/all_activities_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AllActivitiesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchAllActivities() async {
    // Fetch all active polls, quizzes, surveys
    final query = _firestore
        .collection('sponsor_activities')
        .where('status', isEqualTo: 'active')
        .where('type', whereIn: ['poll', 'quiz', 'survey']);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      String typeLabel;
      switch (data['type'] as String?) {
        case 'poll':
          typeLabel = 'Poll';
          break;
        case 'quiz':
          typeLabel = 'Quiz';
          break;
        case 'survey':
          typeLabel = 'Survey';
          break;
        default:
          typeLabel = 'Activity';
      }

      // Estimate time: 1 min per 5 questions (adjust as needed)
      final questions = (data['questions'] as List<dynamic>?) ?? [];
      final estimatedMinutes = (questions.length / 5).ceil().clamp(1, 10);

      final sponsorDetails = data['sponsor_details'] as Map<String, dynamic>?;
      
      // Get reward distribution type
      final rewardDistributionType = data['reward_distribution_type'] as String? ?? 'first_come_first_serve';
      
      // Get start and end dates
      final startDate = data['start_date'] as Timestamp?;
      final endDate = data['end_date'] as Timestamp?;
      
      return {
        'activityId': doc.id,
        'title': data['title'] ?? 'Untitled',
        'desc': data['description'] ?? '',
        'type': typeLabel,
        'points': '${data['reward']?['points'] ?? 0} pts',
        'time': '$estimatedMinutes min',
        'rawType': data['type'], // for navigation
        'sponsorName': sponsorDetails?['name'] ?? data['sponsor_name'] ?? 'Sponsor',
        'sponsorProfilePic': sponsorDetails?['profile_pic'] ?? '',
        'questions': questions,
        'rewardDistributionType': rewardDistributionType,
        'startDate': startDate?.toDate(),
        'endDate': endDate?.toDate(),
      };
    }).toList();
  }

  Future<bool> hasUserAttempted(String userId, String activityId, String rawType) async {
    String collectionName;
    switch (rawType) {
      case 'poll':
        collectionName = 'poll_attempts';
        break;
      case 'quiz':
        collectionName = 'quiz_attempts';
        break;
      case 'survey':
        collectionName = 'survey_attempts';
        break;
      default:
        return false;
    }

    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection(collectionName)
        .doc(activityId)
        .get();

    return doc.exists;
  }
}