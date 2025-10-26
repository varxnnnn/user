import 'package:flutter/foundation.dart';
import 'package:giftardo/core/services/reward_service.dart';

class RewardProvider with ChangeNotifier {
  final RewardService _service = RewardService();
  
  List<Map<String, dynamic>> _rewards = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get rewards => _rewards;
  bool get isLoading => _isLoading;

  Future<void> loadRewards() async {
    _isLoading = true;
    notifyListeners();
    _rewards = await _service.fetchUserRewards();
    _isLoading = false;
    notifyListeners();
  }
}