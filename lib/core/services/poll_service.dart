// service/poll_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class PollService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all polls: sponsor_activities where type == 'poll'
  Future<List<Map<String, dynamic>>> fetchPolls() async {
    // Fetch both active and completed activities (completed = rewards exhausted for first come first serve)
    final query = _firestore
        .collection('sponsor_activities')
        .where('type', isEqualTo: 'poll')
        .where('status', whereIn: ['active', 'completed']);

    final snapshot = await query.get();
    final polls = <Map<String, dynamic>>[];
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
      
      final pollMap = <String, dynamic>{
        'activityId': doc.id,
        'activityTitle': data['title'] ?? '',
        'rewardDescription': data['description'] ?? '',
        'sponsorName': sponsorData?['name'] ?? data['sponsor_name'] ?? 'Sponsor',
        'sponsorProfilePic': sponsorData?['profile_pic'] ?? '',
        'rewardedItem': rewardAlloc?['allocated_quantity'] ?? data['reward']?['points'] ?? 0,
        'rewardType': 'points',
        'rewardDistributionType': data['reward_distribution_type'] ?? 'first_come_first_serve',
        'remainingQuantity': remainingQuantity,
        'activityStatus': activityStatus,
        'isRewardsCompleted': data['reward_distribution_type'] == 'first_come_first_serve' && (remainingQuantity <= 0 || activityStatus == 'completed'),
      };

      // Try to fetch sponsor_rewards if reward_allocation.reward_id exists
      final rewardId = rewardAlloc != null ? (rewardAlloc['reward_id'] as String?) : null;
      if (rewardId != null && rewardId.isNotEmpty) {
        try {
          final rewardDoc = await _firestore.collection('sponsor_rewards').doc(rewardId).get();
          if (rewardDoc.exists) {
            final r = rewardDoc.data()!;
            pollMap['rewardId'] = rewardId;
            pollMap['rewardTitle'] = r['title'] ?? '';
            pollMap['rewardDescription'] = r['description'] ?? pollMap['rewardDescription'];
            pollMap['rewardType'] = (r['type'] ?? 'points').toString().toLowerCase();
            pollMap['rewardAvailableQuantity'] = r['available_quantity'] ?? r['total_quantity'] ?? 0;
            
            // Extract reward data properly from metadata structure
            final metadata = r['metadata'] as Map<String, dynamic>? ?? {};
            final rewardType = pollMap['rewardType'] as String;
            
            if (rewardType == 'voucher') {
              pollMap['rewardData'] = metadata['voucher'] as Map<String, dynamic>? ?? 
                                     r['voucher'] as Map<String, dynamic>? ?? {};
              final voucher = pollMap['rewardData'] as Map<String, dynamic>;
              pollMap['rewardedItem'] = voucher['value'] ?? voucher['amount'] ?? pollMap['rewardedItem'];
            } else if (rewardType == 'coins') {
              pollMap['rewardData'] = metadata['coins'] as Map<String, dynamic>? ?? 
                                     r['coins'] as Map<String, dynamic>? ?? {};
              final coins = pollMap['rewardData'] as Map<String, dynamic>;
              pollMap['rewardedItem'] = coins['amount'] ?? pollMap['rewardedItem'];
            } else if (rewardType == 'product' || rewardType == 'products') {
              pollMap['rewardData'] = metadata['product'] as Map<String, dynamic>? ?? 
                                     r['product'] as Map<String, dynamic>? ?? {};
            } else {
              pollMap['rewardData'] = metadata;
            }
          }
        } catch (_) {}
      }

      polls.add(pollMap);
    }

    return polls;
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