// providers/poll_provider.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/poll_service.dart';

class PollProvider with ChangeNotifier {
  final PollService _pollService = PollService();
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  List<Map<String, dynamic>> _polls = [];
  Map<String, bool> _attemptStatus = {}; // activityId -> attempted
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get polls => _polls;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool isAttempted(String activityId) => _attemptStatus[activityId] ?? false;

  Future<void> loadPolls() async {
    if (_userId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _polls = await _pollService.fetchPolls();

      // Preload attempt status for each poll
      _attemptStatus = {};
      for (var poll in _polls) {
        final activityId = poll['activityId'] as String;
        final attempted = await _pollService.hasUserAttempted(_userId!, activityId);
        _attemptStatus[activityId] = attempted;
      }

      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }

    notifyListeners();
  }
}