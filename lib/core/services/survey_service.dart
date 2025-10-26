// service/survey_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class SurveyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchSurveys() async {
    final query = _firestore
        .collection('sponsor_activities')
        .where('type', isEqualTo: 'survey')
        .where('status', isEqualTo: 'active');

    final snapshot = await query.get();
    final surveys = <Map<String, dynamic>>[];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final sponsorId = data['sponsor_id'] as String?;
      Map<String, dynamic>? sponsorData;
      
      if (sponsorId != null) {
        try {
          final sponsorDoc = await _firestore.collection('sponsors').doc(sponsorId).get();
          if (sponsorDoc.exists) {
            sponsorData = sponsorDoc.data();
          }
        } catch (e) {
          debugPrint('Error fetching sponsor data: $e');
        }
      }

      final surveyMap = <String, dynamic>{
        'activityId': doc.id,
        'activityTitle': data['title'] ?? 'Untitled Survey',
        'rewardDescription': data['description'] ?? '',
        'sponsorName': sponsorData?['name'] ?? data['sponsor_name'] ?? 'Sponsor',
        'sponsorProfilePic': sponsorData?['profile_pic'] ?? '',
        'rewardedItem': data['reward_allocation']?['allocated_quantity'] ?? data['reward']?['points'] ?? 0,
        'rewardType': 'points',
        'questions': (data['questions'] as List<dynamic>?) ?? [],
      };

      final rewardAlloc = data['reward_allocation'] as Map<String, dynamic>?;
      final rewardId = rewardAlloc != null ? (rewardAlloc['reward_id'] as String?) : null;
      if (rewardId != null && rewardId.isNotEmpty) {
        try {
          final rewardDoc = await _firestore.collection('sponsor_rewards').doc(rewardId).get();
          if (rewardDoc.exists) {
            final r = rewardDoc.data()!;
            surveyMap['rewardId'] = rewardId;
            surveyMap['rewardTitle'] = r['title'] ?? '';
            surveyMap['rewardDescription'] = r['description'] ?? surveyMap['rewardDescription'];
            surveyMap['rewardType'] = (r['type'] ?? 'points').toString().toLowerCase();
            surveyMap['rewardAvailableQuantity'] = r['available_quantity'] ?? r['total_quantity'] ?? 0;
            surveyMap['rewardData'] = r['voucher'] ?? r['coins'] ?? r['product'] ?? r['metadata'] ?? {};
            final rd = surveyMap['rewardData'] as Map<String, dynamic>?;
            if (surveyMap['rewardType'] == 'voucher' && rd != null) {
              surveyMap['rewardedItem'] = rd['value'] ?? rd['amount'] ?? surveyMap['rewardedItem'];
            } else if (surveyMap['rewardType'] == 'coins' && rd != null) {
              surveyMap['rewardedItem'] = rd['amount'] ?? surveyMap['rewardedItem'];
            }
          }
        } catch (_) {}
      }

      surveys.add(surveyMap);
    }

    return surveys;
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