// providers/quiz_provider.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/quiz_service.dart';

class QuizProvider with ChangeNotifier {
  final QuizService _quizService = QuizService();
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  List<Map<String, dynamic>> _quizzes = [];
  Map<String, bool> _attemptStatus = {};
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get quizzes => _quizzes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool isAttempted(String activityId) => _attemptStatus[activityId] ?? false;

  Future<void> loadQuizzes() async {
    if (_userId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _quizzes = await _quizService.fetchQuizzes();

      _attemptStatus = {};
      for (var quiz in _quizzes) {
        final activityId = quiz['activityId'] as String;
        final attempted = await _quizService.hasUserAttempted(_userId!, activityId);
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