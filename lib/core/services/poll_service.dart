// service/poll_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
<<<<<<< HEAD
=======
import 'package:flutter/foundation.dart' show debugPrint;
>>>>>>> f9e1824 (newly_updated_4)

class PollService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all polls: sponsor_activities where type == 'poll'
  Future<List<Map<String, dynamic>>> fetchPolls() async {
    final query = _firestore
        .collection('sponsor_activities')
        .where('type', isEqualTo: 'poll')
        .where('status', isEqualTo: 'active');

    final snapshot = await query.get();
<<<<<<< HEAD
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
        
      };
    }).toList();
=======
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

      final pollMap = <String, dynamic>{
        'activityId': doc.id,
        'activityTitle': data['title'] ?? '',
        'rewardDescription': data['description'] ?? '',
        'sponsorName': sponsorData?['name'] ?? data['sponsor_name'] ?? 'Sponsor',
        'sponsorProfilePic': sponsorData?['profile_pic'] ?? '',
        'rewardedItem': data['reward_allocation']?['allocated_quantity'] ?? data['reward']?['points'] ?? 0,
        'rewardType': 'points',
      };

      // Try to fetch sponsor_rewards if reward_allocation.reward_id exists
      final rewardAlloc = data['reward_allocation'] as Map<String, dynamic>?;
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
            pollMap['rewardData'] = r['voucher'] ?? r['coins'] ?? r['product'] ?? r['metadata'] ?? {};
            // set rewardedItem from reward data where appropriate
            final rd = pollMap['rewardData'] as Map<String, dynamic>?;
            if (pollMap['rewardType'] == 'voucher' && rd != null) {
              pollMap['rewardedItem'] = rd['value'] ?? rd['amount'] ?? pollMap['rewardedItem'];
            } else if (pollMap['rewardType'] == 'coins' && rd != null) {
              pollMap['rewardedItem'] = rd['amount'] ?? pollMap['rewardedItem'];
            }
          }
        } catch (_) {}
      }

      polls.add(pollMap);
    }

    return polls;
>>>>>>> f9e1824 (newly_updated_4)
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