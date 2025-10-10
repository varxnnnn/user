import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:giftardo/core/services/reward_allocation_service.dart';
import 'quiz_result_page.dart';

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
  int _rewardPoints = 0;

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

  Future<void> _submitQuiz() async {
    if (_submitted || _questions.isEmpty) return;

    int score = 0;
    bool allCorrect = true;

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (_answers[i] != null && _answers[i] == q['correct_answer']) {
        score++;
      } else {
        allCorrect = false; // mark as not fully correct
      }
    }

    setState(() {
      _submitted = true;
    });

    int finalRewardPoints = _rewardPoints;
    String? rewardCode;

    // Use new reward allocation service if user passed the quiz
    if (allCorrect) {
      final rewardService = RewardAllocationService();

      // Get activity details to find sponsor_id and reward_id
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
          }
        }
      }
    }

    final attemptData = {
      'activityId': widget.activityId,
      'activityTitle': widget.title,
      'description': widget.description,
      'sponsorName': widget.sponsorName,
      'rewardType': widget.rewardType,
      'rewardedItem': finalRewardPoints, // Use actual reward value
      'rewardCode': rewardCode, // Include reward code if available
      'score': score,
      'totalQuestions': _questions.length,
      'answers': _answers,
      'timestamp': FieldValue.serverTimestamp(),
      'rewarded': allCorrect,
      'userId': widget.userId,
    };

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(widget.userId);

      // Save to user's quiz_attempts
      await userDoc.collection('quiz_attempts').doc(widget.activityId).set(attemptData);


      // Increment activitiesCompleted only once
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'activitiesCompleted': FieldValue.increment(1),
      });

      // Navigate to QuizResultPage
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => QuizResultPage(
              activityId: widget.activityId,
              title: widget.title,
              description: widget.description,
              sponsorName: widget.sponsorName,
              sponsorLogo: widget.sponsorLogo,
              rewardType: widget.rewardType,
              rewardedItem: widget.rewardedItem,
              questions: _questions,
              answers: _answers,
              score: score,
              rewarded: allCorrect,
              rewardPoints: finalRewardPoints,
              userId: widget.userId,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz Detail"),
        centerTitle: true,
        backgroundColor: Colors.orange,
      ),
      body: Padding(
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
                  onPressed: _submitted ? null : _submitQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _submitted 
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text("Submitting..."),
                        ],
                      )
                    : const Text("Submit Quiz"),
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
              Text(widget.sponsorName, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("Reward: ${_rewardPoints > 0 ? '$_rewardPoints points' : 'No reward'}"),
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
                Text("${index + 1}. ${q['question_text']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...List<Widget>.generate(
                  (q['options'] as List<dynamic>).length,
                      (optIndex) {
                    final option = q['options'][optIndex];
                    return RadioListTile<String>(
                      value: option,
                      groupValue: _answers[index],
                      onChanged: (value) {
                        setState(() {
                          _answers[index] = value;
                        });
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
