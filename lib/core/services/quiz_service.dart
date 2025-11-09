// service/quiz_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchQuizzes() async {
    // Fetch both active and completed activities (completed = rewards exhausted for first come first serve)
    final query = _firestore
        .collection('sponsor_activities')
        .where('type', isEqualTo: 'quiz')
        .where('status', whereIn: ['active', 'completed']);

    final snapshot = await query.get();
    final quizzes = <Map<String, dynamic>>[];
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final sponsorDetails = data['sponsor_details'] as Map<String, dynamic>?;
      
      // Check if activity is within participation period
      final startDate = (data['start_date'] as Timestamp?)?.toDate();
      final endDate = (data['end_date'] as Timestamp?)?.toDate();
      final now = DateTime.now();
      bool isWithinPeriod = true;
      
      if (startDate != null && endDate != null) {
        isWithinPeriod = !now.isBefore(startDate) && !now.isAfter(endDate);
      }
      
      // Base quiz map
      final rewardAlloc = data['reward_allocation'] as Map<String, dynamic>?;
      final remainingQuantity = rewardAlloc?['remaining_quantity'] as int? ?? 0;
      final activityStatus = data['status'] as String? ?? 'active';
      
      final quizMap = <String, dynamic>{
        'activityId': doc.id,
        'activityTitle': data['title'] ?? 'Untitled Quiz',
        'rewardDescription': data['description'] ?? '',
        'sponsorName': sponsorDetails?['name'] ?? 'Sponsor',
        'sponsorProfilePic': sponsorDetails?['profile_pic'] ?? '',
        'durationSeconds': data['duration_seconds'] ?? 0,
        // fallback: allocated quantity (points) if present
        'rewardedItem': rewardAlloc?['allocated_quantity'] ?? 0,
        'rewardType': 'points',
        'questions': (data['questions'] as List<dynamic>?) ?? [],
        // New fields
        'startDate': startDate,
        'endDate': endDate,
        'isWithinParticipationPeriod': isWithinPeriod,
        'rewardDistributionType': data['reward_distribution_type'] ?? 'first_come_first_serve',
        'remainingQuantity': remainingQuantity,
        'activityStatus': activityStatus,
        'isRewardsCompleted': data['reward_distribution_type'] == 'first_come_first_serve' && (remainingQuantity <= 0 || activityStatus == 'completed'),
      };

      // If activity has a reward allocation pointing to a sponsor_rewards doc, try to fetch it
      final rewardId = rewardAlloc?['reward_id'] as String?;
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
            // Extract reward data properly from metadata structure
            final metadata = r['metadata'] as Map<String, dynamic>? ?? {};
            final rewardType = quizMap['rewardType'] as String;
            
            if (rewardType == 'voucher') {
              quizMap['rewardData'] = metadata['voucher'] as Map<String, dynamic>? ?? 
                                     r['voucher'] as Map<String, dynamic>? ?? {};
              final voucher = quizMap['rewardData'] as Map<String, dynamic>;
              quizMap['rewardedItem'] = voucher['value'] ?? voucher['amount'] ?? quizMap['rewardedItem'];
            } else if (rewardType == 'coins') {
              quizMap['rewardData'] = metadata['coins'] as Map<String, dynamic>? ?? 
                                     r['coins'] as Map<String, dynamic>? ?? {};
              final coins = quizMap['rewardData'] as Map<String, dynamic>;
              quizMap['rewardedItem'] = coins['amount'] ?? quizMap['rewardedItem'];
            } else if (rewardType == 'product' || rewardType == 'products') {
              quizMap['rewardData'] = metadata['product'] as Map<String, dynamic>? ?? 
                                     r['product'] as Map<String, dynamic>? ?? {};
            } else {
              quizMap['rewardData'] = metadata;
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