import 'package:flutter/foundation.dart';
import 'package:giftardo/core/services/milestone_service.dart';

class MilestoneProvider with ChangeNotifier {
  final MilestoneService _service = MilestoneService();
  
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get tasks => _tasks;
  bool get isLoading => _isLoading;
  int get completedCount => _tasks.where((t) => t['completed'] == true).length;
  double get progress => _tasks.isEmpty ? 0 : completedCount / _tasks.length;

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();
    _tasks = await _service.fetchTasks();
    _isLoading = false;
    notifyListeners();
  }
}