import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class YoutubeProvider with ChangeNotifier {
  List<Map<String, dynamic>> _activities = [];
  Map<String, bool> _completionStatus = {};
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get activities => _activities;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool isCompleted(String activityId) => _completionStatus[activityId] ?? false;

  Future<void> loadYoutubeActivities() async {
    if (_isLoading) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get all active YouTube activities
      // Fetch both active and completed activities (completed = rewards exhausted for first come first serve)
      final activitiesSnapshot = await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .where('type', isEqualTo: 'youtube')
          .where('status', whereIn: ['active', 'completed'])
          .get();

      _activities = [];
      _completionStatus = {};

      // Check completion status for each activity
      final futures = <Future<void>>[];
      
      for (final doc in activitiesSnapshot.docs) {
        final data = doc.data();
        final activityId = doc.id;
        
        // Check if user has completed this activity
        futures.add(FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('youtube_attempts')
            .doc(activityId)
            .get()
            .then((doc) {
          _completionStatus[activityId] = doc.exists;
        }));

        // Get reward details
        final rewardAlloc = data['reward_allocation'] as Map<String, dynamic>?;
        final rewardId = rewardAlloc != null ? (rewardAlloc['reward_id'] as String?) : null;
        final remainingQuantity = rewardAlloc?['remaining_quantity'] as int? ?? 0;
        final activityStatus = data['status'] as String? ?? 'active';
        
        Map<String, dynamic> activityMap = {
          'activityId': activityId,
          'activityTitle': data['title'] ?? 'Untitled',
          'description': data['description'] ?? '',
          'type': data['type'],
          'sponsorName': data['sponsor_details']?['name'] ?? 'Sponsor',
          'sponsorProfilePic': data['sponsor_details']?['profile_pic'] ?? '',
          'youtubeLink': data['youtube_link'] ?? '',
          'timerDuration': data['timer_duration'] ?? 60,
          'rewardId': rewardId,
          'rewardDistributionType': data['reward_distribution_type'] ?? 'first_come_first_serve',
          'remainingQuantity': remainingQuantity,
          'activityStatus': activityStatus,
          'isRewardsCompleted': data['reward_distribution_type'] == 'first_come_first_serve' && (remainingQuantity <= 0 || activityStatus == 'completed'),
        };

        // Get reward information if rewardId exists
        if (rewardId != null && rewardId.isNotEmpty) {
          try {
            final rewardDoc = await FirebaseFirestore.instance.collection('sponsor_rewards').doc(rewardId).get();
            if (rewardDoc.exists) {
              final r = rewardDoc.data()!;
              activityMap['rewardTitle'] = r['title'] ?? '';
              activityMap['rewardDescription'] = r['description'] ?? activityMap['rewardDescription'];
              activityMap['rewardType'] = (r['type'] ?? 'points').toString().toLowerCase();
              activityMap['rewardAvailableQuantity'] = r['available_quantity'] ?? r['total_quantity'] ?? 0;
              
              // Extract reward data properly from metadata structure
              final metadata = r['metadata'] as Map<String, dynamic>? ?? {};
              final rewardType = activityMap['rewardType'] as String;
              
              if (rewardType == 'voucher') {
                activityMap['rewardData'] = metadata['voucher'] as Map<String, dynamic>? ?? 
                                           r['voucher'] as Map<String, dynamic>? ?? {};
                final voucher = activityMap['rewardData'] as Map<String, dynamic>;
                activityMap['rewardedItem'] = voucher['value'] ?? voucher['amount'] ?? activityMap['rewardedItem'];
              } else if (rewardType == 'coins') {
                activityMap['rewardData'] = metadata['coins'] as Map<String, dynamic>? ?? 
                                           r['coins'] as Map<String, dynamic>? ?? {};
                final coins = activityMap['rewardData'] as Map<String, dynamic>;
                activityMap['rewardedItem'] = coins['amount'] ?? activityMap['rewardedItem'];
              } else if (rewardType == 'product' || rewardType == 'products') {
                activityMap['rewardData'] = metadata['product'] as Map<String, dynamic>? ?? 
                                           r['product'] as Map<String, dynamic>? ?? {};
              } else {
                activityMap['rewardData'] = metadata;
              }
            }
          } catch (_) {}
        }

        _activities.add(activityMap);
      }
      
      // Wait for all completion status checks
      await Future.wait(futures);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading YouTube activities: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark an activity as completed locally and notify listeners so UI updates immediately.
  void markCompleted(String activityId) {
    _completionStatus[activityId] = true;
    notifyListeners();
  }

  void reset() {
    _activities = [];
    _completionStatus = {};
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}