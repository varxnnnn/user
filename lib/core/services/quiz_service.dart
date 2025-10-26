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
    final quizzes = <Map<String, dynamic>>[];
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final sponsorDetails = data['sponsor_details'] as Map<String, dynamic>?;
      // Base quiz map
      final quizMap = <String, dynamic>{
        'activityId': doc.id,
        'activityTitle': data['title'] ?? 'Untitled Quiz',
        'rewardDescription': data['description'] ?? '',
        'sponsorName': sponsorDetails?['name'] ?? 'Sponsor',
        'sponsorProfilePic': sponsorDetails?['profile_pic'] ?? '',
        'durationSeconds': data['duration_seconds'] ?? 0,
        // fallback: allocated quantity (points) if present
        'rewardedItem': data['reward_allocation']?['allocated_quantity'] ?? 0,
        'rewardType': 'points',
        'questions': (data['questions'] as List<dynamic>?) ?? [],
      };

      // If activity has a reward allocation pointing to a sponsor_rewards doc, try to fetch it
      final rewardAlloc = data['reward_allocation'] as Map<String, dynamic>?;
      final rewardId = rewardAlloc != null ? (rewardAlloc['reward_id'] as String?) : null;
      if (rewardId != null && rewardId.isNotEmpty) {
        try {
          final rewardDoc = await _firestore.collection('sponsor_rewards').doc(rewardId).get();
          if (rewardDoc.exists) {
            final r = rewardDoc.data()!;
            // common fields
            quizMap['rewardId'] = rewardId;
            quizMap['rewardTitle'] = r['title'] ?? '';
            quizMap['rewardDescription'] = r['description'] ?? quizMap['rewardDescription'];
            quizMap['rewardType'] = (r['type'] ?? 'points').toString().toLowerCase();
            quizMap['rewardAvailableQuantity'] = r['available_quantity'] ?? r['total_quantity'] ?? 0;
            // type-specific payloads
            if (quizMap['rewardType'] == 'voucher') {
              quizMap['rewardData'] = r['voucher'] ?? r['metadata'] ?? {};
            } else if (quizMap['rewardType'] == 'coins') {
              quizMap['rewardData'] = r['coins'] ?? r['metadata'] ?? {};
            } else if (quizMap['rewardType'] == 'product' || quizMap['rewardType'] == 'products') {
              quizMap['rewardData'] = r['product'] ?? r['metadata'] ?? {};
            } else {
              quizMap['rewardData'] = r['metadata'] ?? {};
            }

            // If the reward document contains a numeric value (e.g., coins.amount or voucher.value), try to set rewardedItem
            if (quizMap['rewardType'] == 'voucher') {
              final voucher = quizMap['rewardData'] as Map<String, dynamic>?;
              quizMap['rewardedItem'] = voucher != null ? (voucher['value'] ?? voucher['amount'] ?? quizMap['rewardedItem']) : quizMap['rewardedItem'];
            } else if (quizMap['rewardType'] == 'coins') {
              final coins = quizMap['rewardData'] as Map<String, dynamic>?;
              quizMap['rewardedItem'] = coins != null ? (coins['amount'] ?? quizMap['rewardedItem']) : quizMap['rewardedItem'];
            }
          }
        } catch (_) {
          // ignore reward fetch errors, keep base values
        }
      }

      quizzes.add(quizMap);
    }
    
    return quizzes;
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