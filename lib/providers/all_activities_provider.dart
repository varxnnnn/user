// providers/all_activities_provider.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/all_activities_service.dart';

class AllActivitiesProvider with ChangeNotifier {
  final AllActivitiesService _service = AllActivitiesService();
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  List<Map<String, dynamic>> _activities = [];
  Map<String, bool> _attemptStatus = {};
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get quickEarnList => _activities;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool isAttempted(String activityId) => _attemptStatus[activityId] ?? false;

  Future<void> loadAllActivities() async {
    if (_userId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _activities = await _service.fetchAllActivities();

      // Load attempt status
      _attemptStatus = {};
      for (var act in _activities) {
        final id = act['activityId'] as String;
        final rawType = act['rawType'] as String;
        final attempted = await _service.hasUserAttempted(_userId!, id, rawType);
        _attemptStatus[id] = attempted;
      }

      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }

    notifyListeners();
  }
}