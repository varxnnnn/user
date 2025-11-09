import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class YoutubeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Checks if a user has completed a YouTube activity
  Future<bool> hasUserCompleted(String userId, String activityId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('youtube_attempts')
          .doc(activityId)
          .get();

      return doc.exists;
    } catch (e) {
      print('Error checking YouTube completion: $e');
      return false;
    }
  }

  /// Records a YouTube activity completion
  Future<void> recordCompletion({
    required String userId,
    required String activityId,
    required String activityTitle,
    required String sponsorName,
    required String rewardType,
    required dynamic rewardedItem,
    String? rewardCode,
    String? rewardTitle,
    String? rewardDescription,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('youtube_attempts')
          .doc(activityId)
          .set({
        'activityId': activityId,
        'activityTitle': activityTitle,
        'sponsorName': sponsorName,
        'rewardType': rewardType,
        'rewardedItem': rewardedItem,
        'rewardCode': rewardCode,
        'rewardTitle': rewardTitle,
        'rewardDescription': rewardDescription,
        'timestamp': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error recording YouTube completion: $e');
      rethrow;
    }
  }

  /// Fetches all YouTube activities for a user
  Future<List<Map<String, dynamic>>> fetchUserYoutubeActivities(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('youtube_attempts')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'activityId': data['activityId'],
          'activityTitle': data['activityTitle'],
          'sponsorName': data['sponsorName'],
          'rewardType': data['rewardType'],
          'rewardedItem': data['rewardedItem'],
          'rewardCode': data['rewardCode'],
          'timestamp': data['timestamp'],
        };
      }).toList();
    } catch (e) {
      print('Error fetching user YouTube activities: $e');
      return [];
    }
  }
}