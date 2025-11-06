// providers/survey_provider.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/survey_service.dart';

class SurveyProvider with ChangeNotifier {
  final SurveyService _surveyService = SurveyService();
  // Resolve user id dynamically to avoid capturing null at construction time
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  List<Map<String, dynamic>> _surveys = [];
  Map<String, bool> _completionStatus = {};
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get surveys => _surveys;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool isCompleted(String activityId) => _completionStatus[activityId] ?? false;

  Future<void> loadSurveys() async {
    if (_userId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _surveys = await _surveyService.fetchSurveys();

      _completionStatus = {};
      for (var survey in _surveys) {
        final activityId = survey['activityId'] as String;
        final completed = await _surveyService.hasUserCompleted(_userId!, activityId);
        _completionStatus[activityId] = completed;
      }

      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }

    notifyListeners();
  }

  /// Mark an activity as completed locally and notify listeners so UI updates immediately.
  void markAttempted(String activityId) {
    _completionStatus[activityId] = true;
    notifyListeners();
  }
}