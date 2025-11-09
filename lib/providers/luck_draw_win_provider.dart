import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LuckDrawWinProvider with ChangeNotifier {
  List<Map<String, dynamic>> _wins = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get wins => _wins;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadWins() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('luck_draw_rewards')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('awarded_at', descending: true)
          .get();

      _wins = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'activityId': data['activity_id'],
          'rewardId': data['reward_id'],
          'rewardTitle': data['reward_title'] ?? 'Reward',
          'rewardDescription': data['reward_description'] ?? '',
          'rewardType': data['reward_type'] ?? 'points',
          'rewardData': data['reward_data'] as Map<String, dynamic>? ?? {},
          'awardedAt': data['awarded_at'],
          'activityTitle': data['activity_title'] ?? 'Luck Draw Activity',
        };
      }).toList();

      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }

    notifyListeners();
  }
}