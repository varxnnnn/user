// service/survey_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class SurveyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchSurveys() async {
    // Fetch both active and completed activities (completed = rewards exhausted for first come first serve)
    final query = _firestore
        .collection('sponsor_activities')
        .where('type', isEqualTo: 'survey')
        .where('status', whereIn: ['active', 'completed']);

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

      final rewardAlloc = data['reward_allocation'] as Map<String, dynamic>?;
      final remainingQuantity = rewardAlloc?['remaining_quantity'] as int? ?? 0;
      final activityStatus = data['status'] as String? ?? 'active';
      
      final surveyMap = <String, dynamic>{
        'activityId': doc.id,
        'activityTitle': data['title'] ?? 'Untitled Survey',
        'rewardDescription': data['description'] ?? '',
        'sponsorName': sponsorData?['name'] ?? data['sponsor_name'] ?? 'Sponsor',
        'sponsorProfilePic': sponsorData?['profile_pic'] ?? '',
        'rewardedItem': rewardAlloc?['allocated_quantity'] ?? data['reward']?['points'] ?? 0,
        'rewardType': 'points',
        'questions': (data['questions'] as List<dynamic>?) ?? [],
        'rewardDistributionType': data['reward_distribution_type'] ?? 'first_come_first_serve',
        'remainingQuantity': remainingQuantity,
        'activityStatus': activityStatus,
        'isRewardsCompleted': data['reward_distribution_type'] == 'first_come_first_serve' && (remainingQuantity <= 0 || activityStatus == 'completed'),
      };
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
            
            // Extract reward data properly from metadata structure
            final metadata = r['metadata'] as Map<String, dynamic>? ?? {};
            final rewardType = surveyMap['rewardType'] as String;
            
            if (rewardType == 'voucher') {
              surveyMap['rewardData'] = metadata['voucher'] as Map<String, dynamic>? ?? 
                                       r['voucher'] as Map<String, dynamic>? ?? {};
              final voucher = surveyMap['rewardData'] as Map<String, dynamic>;
              surveyMap['rewardedItem'] = voucher['value'] ?? voucher['amount'] ?? surveyMap['rewardedItem'];
            } else if (rewardType == 'coins') {
              surveyMap['rewardData'] = metadata['coins'] as Map<String, dynamic>? ?? 
                                       r['coins'] as Map<String, dynamic>? ?? {};
              final coins = surveyMap['rewardData'] as Map<String, dynamic>;
              surveyMap['rewardedItem'] = coins['amount'] ?? surveyMap['rewardedItem'];
            } else if (rewardType == 'product' || rewardType == 'products') {
              surveyMap['rewardData'] = metadata['product'] as Map<String, dynamic>? ?? 
                                       r['product'] as Map<String, dynamic>? ?? {};
            } else {
              surveyMap['rewardData'] = metadata;
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