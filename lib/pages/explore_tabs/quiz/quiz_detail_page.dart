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
  int _score = 0;
  bool _rewarded = false;
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
      _score = score;
      _rewarded = allCorrect; // reward only if all answers are correct
    });

    final attemptData = {
      'activityId': widget.activityId,
      'activityTitle': widget.title,
      'description': widget.description,
      'sponsorName': widget.sponsorName,
      'rewardType': widget.rewardType,
      'rewardedItem': _rewarded ? _rewardPoints : 0,
      'score': score,
      'totalQuestions': _questions.length,
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

      // Add reward points to user's points if activity is completed successfully
      if (_rewarded && _rewardPoints > 0) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .update({
          'points': FieldValue.increment(_rewardPoints),
        });
      }

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
        'rewardedItem': _rewarded ? _rewardPoints : 0,
        'timestamp': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      debugPrint("Error saving quiz attempt: $e");
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
                  : _submitted
                      ? _buildAnalysis()
                      : _buildQuestions(),
            ),
            if (!_submitted && !_loadingQuestions && _questions.isNotEmpty)
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

  Widget _buildAnalysis() {
    return ListView.builder(
      itemCount: _questions.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Show overall score at top
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Quiz Completed!", style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text("Score: $_score / ${_questions.length}"),
              Text("Reward: ${_rewarded ? '$_rewardPoints points' : 'Not rewarded'}"),
              const SizedBox(height: 16),
            ],
          );
        }
        final q = _questions[index - 1];
        final userAnswer = _answers[index - 1];
        final correctAnswer = q['correct_answer'];
        final isCorrect = userAnswer == correctAnswer;

        return Card(
          color: isCorrect ? Colors.green[100] : Colors.red[100],
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(q['question_text']),
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
