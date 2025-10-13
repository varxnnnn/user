import 'package:flutter/foundation.dart';
import 'package:giftardo/core/services/reward_allocation_service.dart';

class RewardsDisplayProvider with ChangeNotifier {
  final RewardAllocationService _rewardService = RewardAllocationService();
  
  List<Map<String, dynamic>> _earnedRewards = [];
  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> get earnedRewards => _earnedRewards;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUserRewards(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _earnedRewards = await _rewardService.getUserEarnedRewards(userId);
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }

    notifyListeners();
  }

  int get totalRewardsEarned {
    return _earnedRewards.fold(0, (sum, reward) => sum + (reward['reward_value'] as int? ?? 0));
  }

  int get totalActivitiesCompleted {
    return _earnedRewards.length;
  }

  List<Map<String, dynamic>> get recentRewards {
    // Return last 5 rewards
    return _earnedRewards.take(5).toList();
  }
}

