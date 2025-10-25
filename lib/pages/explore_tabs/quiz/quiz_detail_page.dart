import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:giftardo/core/services/reward_allocation_service.dart';
import 'quiz_result_page.dart';
import 'package:provider/provider.dart';
import '../../../providers/quiz_provider.dart';

class QuizDetailPage extends StatefulWidget {
  final String activityId;
  final String title;
  final String description;
  final String sponsorName;
  final String sponsorLogo;
  final String rewardType;
  final dynamic rewardedItem;
  final List<Map<String, dynamic>> questions;
  final dynamic pointsAwarded;
  final String userId;

  const QuizDetailPage({
    Key? key,
    required this.activityId,
    required this.title,
    required this.description,
    required this.sponsorName,
    required this.sponsorLogo,
    required this.rewardType,
    required this.rewardedItem,
    required this.questions,
    required this.pointsAwarded,
    required this.userId,
  }) : super(key: key);

  @override
  State<QuizDetailPage> createState() => _QuizDetailPageState();
}

class _QuizDetailPageState extends State<QuizDetailPage> {
  late List<String?> _answers;
  bool _submitted = false;
  List<Map<String, dynamic>> _questions = [];
  bool _loadingQuestions = true;
  bool _isSubmitting = false; // <-- NEW: track submission state
  int _rewardPoints = 0;
  String? _rewardTitle;
  String? _rewardDescription;

  @override
  void initState() {
    super.initState();
    _loadActivityDetails();
    _loadQuestions();
  }

  Future<void> _loadActivityDetails() async {
    try {
      final activityDoc = await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(widget.activityId)
          .get();

      if (activityDoc.exists) {
        final data = activityDoc.data()!;
        setState(() {
          _rewardPoints = data['cost_points'] ?? 0;
          final rewardAlloc = data['reward_allocation'] as Map<String, dynamic>?;
          if (rewardAlloc != null && rewardAlloc['reward_id'] != null) {
            FirebaseFirestore.instance
                .collection('sponsor_rewards')
                .doc(rewardAlloc['reward_id'] as String)
                .get()
                .then((rdoc) {
              if (rdoc.exists) {
                final rdata = rdoc.data()!;
                setState(() {
                  _rewardTitle = rdata['title'] as String?;
                  _rewardDescription = rdata['description'] as String?;
                });
              }
            }).catchError((_) {});
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading activity details: $e");
    }
  }

  Future<void> _loadQuestions() async {
    try {
      final questionsSnapshot = await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(widget.activityId)
          .collection('questions')
          .get();

      final questions = questionsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'question_text': data['question_text'],
          'options': data['options'],
          'correct_answer': data['correct_answer'],
          'created_at': data['created_at'],
        };
      }).toList();

      setState(() {
        _questions = questions;
        _answers = List<String?>.filled(questions.length, null);
        _loadingQuestions = false;
      });
    } catch (e) {
      debugPrint("Error loading questions: $e");
      setState(() {
        _loadingQuestions = false;
      });
    }
  }

  Future<void> _saveAbandonedAttempt() async {
    final attemptData = {
      'activityId': widget.activityId,
      'activityTitle': widget.title,
      'description': widget.description,
      'sponsorName': widget.sponsorName,
      'rewardType': widget.rewardType,
      'rewardedItem': 0,
      'rewardCode': null,
      'rewardTitle': null,
      'rewardDescription': null,
      'score': 0,
      'totalQuestions': _questions.length,
      'answers': _answers,
      'timestamp': FieldValue.serverTimestamp(),
      'rewarded': false,
      'userId': widget.userId,
      'isAbandoned': true,
    };

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(widget.userId);
      await userDoc.collection('quiz_attempts').doc(widget.activityId).set(attemptData, SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'activitiesCompleted': FieldValue.increment(1)});
    } catch (e) {
      debugPrint("Error saving abandoned quiz attempt: $e");
    }
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Exit Quiz?"),
        content: const Text("Are you sure you want to exit? Your progress will be saved as completed."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes"),
          ),
        ],
      ),
    ) ??
        false;

    if (shouldPop) {
      await _saveAbandonedAttempt();
      if (mounted) Navigator.of(context).pop();
    }
    return shouldPop;
  }

  Future<void> _submitQuiz() async {
    if (_submitted || _questions.isEmpty || _isSubmitting) return;

    // Validate all answered
    for (int i = 0; i < _answers.length; i++) {
      if (_answers[i] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please answer all questions")),
        );
        return;
      }
    }

    setState(() {
      _submitted = true;
      _isSubmitting = true; // <-- Enable loading
    });

    int score = 0;
    bool allCorrect = true;

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (_answers[i] != null && _answers[i] == q['correct_answer']) {
        score++;
      } else {
        allCorrect = false;
      }
    }

    int finalRewardPoints = _rewardPoints;
    String? rewardCode;
    String? actualRewardType;
    String? rewardTitle;
    String? rewardDescription;

    try {
      if (allCorrect) {
        final rewardService = RewardAllocationService();
        final activityDoc = await FirebaseFirestore.instance
            .collection('sponsor_activities')
            .doc(widget.activityId)
            .get();

        if (activityDoc.exists) {
          final activityData = activityDoc.data()!;
          final sponsorId = activityData['sponsor_id'] as String?;
          final rewardAllocation = activityData['reward_allocation'] as Map<String, dynamic>?;
          final rewardId = rewardAllocation?['reward_id'] as String?;

          if (sponsorId != null && rewardId != null) {
            final rewardResult = await rewardService.allocateRewardToUser(
              activityId: widget.activityId,
              userId: widget.userId,
              sponsorId: sponsorId,
              rewardId: rewardId,
            );

            if (rewardResult != null) {
              finalRewardPoints = rewardResult['reward_value'] as int? ?? 0;
              rewardCode = rewardResult['reward_code'] as String?;
              actualRewardType = rewardResult['reward_type'] as String? ?? 'points';
              rewardTitle = rewardResult['reward_title'] as String? ?? 'Reward';
              rewardDescription = rewardResult['reward_description'] as String? ?? '';
            }
          }
        }
      }

      final attemptData = {
        'activityId': widget.activityId,
        'activityTitle': widget.title,
        'description': widget.description,
        'sponsorName': widget.sponsorName,
        'rewardType': actualRewardType ?? widget.rewardType,
        'rewardedItem': finalRewardPoints,
        'rewardCode': rewardCode,
        'rewardTitle': rewardTitle,
        'rewardDescription': rewardDescription,
        'score': score,
        'totalQuestions': _questions.length,
        'answers': _answers,
        'timestamp': FieldValue.serverTimestamp(),
        'rewarded': allCorrect,
        'userId': widget.userId,
      };

      final userDoc = FirebaseFirestore.instance.collection('users').doc(widget.userId);
      await userDoc.collection('quiz_attempts').doc(widget.activityId).set(attemptData);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'activitiesCompleted': FieldValue.increment(1)});

      if (mounted) {
        // mark in provider so the quizzes list updates immediately
        try {
          Provider.of<QuizProvider>(context, listen: false).markAttempted(widget.activityId);
        } catch (_) {}
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => QuizResultPage(
              activityId: widget.activityId,
              title: widget.title,
              description: widget.description,
              sponsorName: widget.sponsorName,
              sponsorLogo: widget.sponsorLogo,
              rewardType: actualRewardType ?? widget.rewardType,
              rewardedItem: widget.rewardedItem,
              questions: _questions,
              answers: _answers,
              score: score,
              rewarded: allCorrect,
              rewardPoints: finalRewardPoints,
              userId: widget.userId,
              rewardCode: rewardCode,
              rewardTitle: rewardTitle,
              rewardDescription: rewardDescription,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving quiz attempt: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error submitting quiz: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          // Note: we don't reset _submitted because we navigate away
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Quiz Detail"),
          centerTitle: true,
          backgroundColor: Colors.orange,
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _loadingQuestions
                        ? const Center(child: CircularProgressIndicator())
                        : _buildQuestions(),
                  ),
                  if (!_submitted && !_loadingQuestions && _questions.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitQuiz,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isSubmitting
                            ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              "Submitting",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ],
                        )
                            : const Text("Submit Quiz"),
                      ),
                    ),
                ],
              ),
            ),
            // Full-screen loading overlay
            if (_isSubmitting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.orange,
          child: Text(
            widget.sponsorName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.sponsorName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_rewardTitle != null) ...[
                Text(
                  _rewardTitle!,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (_rewardDescription != null)
                  Text(
                    _rewardDescription!,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
              ] else ...[
                Text(
                  "Reward: ${_rewardPoints > 0 ? '$_rewardPoints points' : 'No reward'}",
                ),
              ],
              Text(widget.title, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestions() {
    if (_questions.isEmpty) {
      return const Center(
        child: Text(
          "No questions available for this quiz.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final q = _questions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${index + 1}. ${q['question_text']}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...List<Widget>.generate(
                  (q['options'] as List<dynamic>).length,
                      (optIndex) {
                    final option = q['options'][optIndex];
                    return RadioListTile<String>(
                      value: option,
                      groupValue: _answers[index],
                      onChanged: (value) {
                        if (!_submitted && !_isSubmitting) {
                          setState(() {
                            _answers[index] = value;
                          });
                        }
                      },
                      title: Text(option),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}