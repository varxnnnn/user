import 'package:flutter/foundation.dart';
import 'package:giftardo/core/services/home_service.dart';

class HomeProvider with ChangeNotifier {
  final HomeService _service = HomeService();

  // State
  int _walletAmount = 0;
  List<Map<String, dynamic>> _rewardCards = [];
  List<Map<String, dynamic>> _vouchers = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _winners = [];
  bool _isLoading = true;

  // Getters
  int get walletAmount => _walletAmount;
  List<Map<String, dynamic>> get rewardCards => _rewardCards;
  List<Map<String, dynamic>> get vouchers => _vouchers;
  List<Map<String, dynamic>> get tasks => _tasks;
  List<Map<String, dynamic>> get winners => _winners;
  bool get isLoading => _isLoading;

  // Fetch all data
  Future<void> loadHomePageData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _walletAmount = await _service.fetchWalletPoints();
      _rewardCards = await _service.fetchRewardCards();
      _vouchers = await _service.fetchVouchers();
      _tasks = await _service.fetchOngoingTasks();
      _winners = await _service.fetchTopWinners();
    } catch (e) {
      // Handle error (optional)
    }

    _isLoading = false;
    notifyListeners();
  }
}