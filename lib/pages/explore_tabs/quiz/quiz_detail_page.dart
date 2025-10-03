import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuizDetailPage extends StatefulWidget {
  final String activityId;
  final String title;
  final String description;
  final String sponsorName;
  final String sponsorLogo;
  final String rewardType;
  final dynamic rewardedItem;
  final List<Map<String, dynamic>> questions;
  final int durationSeconds;
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
    required this.durationSeconds,
    required this.pointsAwarded,
    required this.userId,
  }) : super(key: key);

  @override
  State<QuizDetailPage> createState() => _QuizDetailPageState();
}

class _QuizDetailPageState extends State<QuizDetailPage> {
  late List<String?> _answers;
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _submitted = false;
  int _score = 0;
  bool _rewarded = false;

  @override
  void initState() {
    super.initState();
    _answers = List<String?>.filled(widget.questions.length, null);
    _remainingSeconds = widget.durationSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        _submitQuiz();
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  Future<void> _submitQuiz() async {
    if (_submitted) return;
    _timer?.cancel();

    int score = 0;
    bool allCorrect = true;

    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      if (_answers[i] != null && _answers[i] == q['answer']) {
        score++;
      } else {
        allCorrect = false; // mark as not fully correct
      }
    }

    setState(() {
      _submitted = true;
      _score = score;
      _rewarded = allCorrect; // reward only if all answers are correct
    });

    final attemptData = {
      'activityId': widget.activityId,
      'activityTitle': widget.title,
      'description': widget.description,
      'sponsorName': widget.sponsorName,
      'rewardType': widget.rewardType,
      'rewardedItem': _rewarded ? widget.rewardedItem : 0,
      'score': score,
      'totalQuestions': widget.questions.length,
      'answers': _answers,
      'timestamp': FieldValue.serverTimestamp(),
      'rewarded': _rewarded,
      'userId': widget.userId,
    };

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(widget.userId);

      // Save to user's quiz_attempts
      await userDoc.collection('quiz_attempts').doc(widget.activityId).set(attemptData);

      // Save under sponsor activities sub collection
      await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc('sub')
          .collection('quiz')
          .doc(widget.activityId)
          .collection('users')
          .doc(widget.userId)
          .set(attemptData);

      // Save under sponsor activities all collection
      await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc('all')
          .collection('all_act')
          .doc(widget.activityId)
          .collection('users')
          .doc(widget.userId)
          .set(attemptData);

      // Increment activitiesCompleted only once
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'activitiesCompleted': FieldValue.increment(1),
      });

      // Add reward to rewards_earned collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('rewards_earned')
          .doc(widget.activityId)
          .set({
        'activityId': widget.activityId,
        'activityTitle': widget.title,
        'rewardType': widget.rewardType,
        'rewardedItem': widget.rewardedItem,
        'timestamp': FieldValue.serverTimestamp(),
      });


    } catch (e) {
      debugPrint("Error saving quiz attempt: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
            if (!_submitted) _buildTimer(),
            const SizedBox(height: 16),
            Expanded(child: _submitted ? _buildAnalysis() : _buildQuestions()),
            if (!_submitted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitQuiz,
                  child: const Text("Submit"),
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
              Text("Reward: ${widget.rewardedItem}"),
              Text(widget.title, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.timer),
        const SizedBox(width: 8),
        Text(_formatTime(_remainingSeconds),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildQuestions() {
    return ListView.builder(
      itemCount: widget.questions.length,
      itemBuilder: (context, index) {
        final q = widget.questions[index];
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
                Text("${index + 1}. ${q['question']}", style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildAnalysis() {
    return ListView.builder(
      itemCount: widget.questions.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Show overall score at top
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Quiz Completed!", style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text("Score: $_score / ${widget.questions.length}"),
              Text("Reward: ${_rewarded ? widget.rewardedItem : 'Not rewarded'}"),
              const SizedBox(height: 16),
            ],
          );
        }
        final q = widget.questions[index - 1];
        final userAnswer = _answers[index - 1];
        final correctAnswer = q['answer'];
        final isCorrect = userAnswer == correctAnswer;

        return Card(
          color: isCorrect ? Colors.green[100] : Colors.red[100],
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(q['question']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Your Answer: ${userAnswer ?? 'Not answered'}"),
                Text("Correct Answer: $correctAnswer"),
              ],
            ),
          ),
        );
      },
    );
  }
}
