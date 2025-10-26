// providers/quiz_provider.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/quiz_service.dart';

class QuizProvider with ChangeNotifier {
  final QuizService _quizService = QuizService();
  // Resolve user id dynamically to avoid capturing null at construction time
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

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

      // Build attempt status in parallel for speed
      final futures = <Future<void>>[];
      _attemptStatus = {};
      for (var quiz in _quizzes) {
        final activityId = quiz['activityId'] as String;
        futures.add(_quizService.hasUserAttempted(_userId!, activityId).then((attempted) {
          _attemptStatus[activityId] = attempted;
        }));
      }
      await Future.wait(futures);

      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }

    notifyListeners();
  }

  /// Mark an activity as attempted locally and notify listeners so UI updates immediately.
  void markAttempted(String activityId) {
    _attemptStatus[activityId] = true;
    notifyListeners();
  }
}
