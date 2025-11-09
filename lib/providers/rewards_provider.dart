import 'package:flutter/foundation.dart';
import 'package:giftardo/core/services/reward_allocation_service.dart';

class RewardsProvider with ChangeNotifier {
  final RewardAllocationService _rewardService = RewardAllocationService();
  
  List<Map<String, dynamic>> _rewards = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get rewards => _rewards;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRewards() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // We'll need to get the current user ID - for now, we'll assume this is handled elsewhere
      // In a real implementation, you'd get the user ID from auth provider
      // _rewards = await _rewardService.getUserRewards(userId);
      _rewards = []; // Placeholder until we have user ID
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }

    notifyListeners();
  }

  // Method to load rewards for a specific user
  Future<void> loadRewardsForUser(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _rewards = await _rewardService.getUserRewards(userId);
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }

    notifyListeners();
  }
}