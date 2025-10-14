import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:giftardo/core/services/reward_allocation_service.dart';

/// ----------------------
/// Poll Detail Page
/// ----------------------
class PollDetailPage extends StatefulWidget {
  final String userId;
  final String activityId;
  final String title;
  final String description;
  final String sponsorName;
  final String sponsorLogo;
  final int pointsAwarded;
  final String rewardType;

  const PollDetailPage({
    Key? key,
    required this.userId,
    required this.activityId,
    required this.title,
    required this.description,
    required this.sponsorName,
    required this.sponsorLogo,
    required this.pointsAwarded,
    required this.rewardType, required List<Map<String, dynamic>> questions,
  }) : super(key: key);

  @override
  State<PollDetailPage> createState() => _PollDetailPageState();
}

class _PollDetailPageState extends State<PollDetailPage> {
  List<Map<String, dynamic>> _questions = [];
  final Map<int, String> _answers = {};
  bool _loadingQuestions = true;
  bool _isSubmitting = false;
  int _actualRewardValue = 0;

  @override
  void initState() {
    super.initState();
    _loadPollQuestions();
  }

  Future<void> _loadPollQuestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(widget.activityId)
          .collection('questions')
          .get();

      final questions = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'question_text': data['question_text'],
          'options': List<String>.from(data['options'] ?? []),
          'votes': List<int>.from(data['votes'] ?? []),
        };
      }).toList();

      setState(() {
        _questions = questions;
        _loadingQuestions = false;
      });
    } catch (e) {
      debugPrint("Error loading poll questions: $e");
      setState(() {
        _loadingQuestions = false;
      });
    }
  }

  Future<void> _submitPoll() async {
    if (_answers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please answer all questions")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Update votes for each question
      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final selectedOption = _answers[i];
        if (selectedOption != null) {
          final optionIndex = q['options'].indexOf(selectedOption);
          if (optionIndex >= 0) {
            q['votes'][optionIndex] = (q['votes'][optionIndex] ?? 0) + 1;

            // Update Firestore
            await FirebaseFirestore.instance
                .collection('sponsor_activities')
                .doc(widget.activityId)
                .collection('questions')
                .doc(q['id'])
                .update({'votes': q['votes']});
          }
        }
      }

      // Save user's poll attempt
      final userRef =
      FirebaseFirestore.instance.collection('users').doc(widget.userId);
      await userRef.collection('poll_attempts').doc(widget.activityId).set({
        'activityId': widget.activityId,
        'activityTitle': widget.title,
        'description': widget.description,
        'sponsorName': widget.sponsorName,
        'rewardType': widget.rewardType,
        'rewardedItem': 0,
        'answers': _answers.map((k, v) => MapEntry(k.toString(), v)),
        'timestamp': FieldValue.serverTimestamp(),
        'userId': widget.userId,
      });

      // Allocate reward using RewardAllocationService
      final rewardService = RewardAllocationService();
      final activityDoc = await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(widget.activityId)
          .get();

      if (activityDoc.exists) {
        final activityData = activityDoc.data()!;
        final sponsorId = activityData['sponsor_id'] as String?;
        final rewardAllocation =
        activityData['reward_allocation'] as Map<String, dynamic>?;
        final rewardId = rewardAllocation?['reward_id'] as String?;

        if (sponsorId != null && rewardId != null) {
          final rewardResult = await rewardService.allocateRewardToUser(
            activityId: widget.activityId,
            userId: widget.userId,
            sponsorId: sponsorId,
            rewardId: rewardId,
          );

          if (rewardResult != null) {
            _actualRewardValue = rewardResult['reward_value'] as int? ?? 0;
          }
        }
      }

      // Navigate to Poll Result Page
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PollResultPage(
              title: widget.title,
              questions: _questions,
              answers: _answers,
              rewardedItem:
              _actualRewardValue > 0 ? _actualRewardValue : widget.pointsAwarded,
              rewardType: widget.rewardType,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting poll: $e")),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.orange,
      ),
      body: _loadingQuestions
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _questions.length,
        itemBuilder: (context, index) {
          final question = _questions[index]['question_text'];
          final options = List<String>.from(_questions[index]['options']);

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...options.map((option) {
                    return RadioListTile<String>(
                      title: Text(option),
                      value: option,
                      groupValue: _answers[index],
                      onChanged: (val) =>
                          setState(() => _answers[index] = val!),
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitPoll,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Submit Poll",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

/// ----------------------
/// Poll Result Page
/// ----------------------
class PollResultPage extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> questions;
  final Map<int, String> answers;
  final int rewardedItem;
  final String rewardType;

  const PollResultPage({
    super.key,
    required this.title,
    required this.questions,
    required this.answers,
    required this.rewardedItem,
    required this.rewardType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Poll Results"),
        backgroundColor: Colors.green,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Card(
              color: Colors.green[50],
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 64),
                    const SizedBox(height: 16),
                    Text("✅ You completed the poll \"$title\"!",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text(
                        "You have received $rewardedItem $rewardType",
                        style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            );
          }

          final q = questions[index - 1];
          final userAnswer = answers[index - 1];
          final options = List<String>.from(q['options']);
          final votes = List<int>.from(q['votes']);
          final totalVotes = votes.fold(0, (a, b) => a + b);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${index}. ${q['question_text']}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...List.generate(options.length, (i) {
                    final option = options[i];
                    final voteCount = votes[i];
                    final percentage =
                    totalVotes > 0 ? (voteCount / totalVotes) * 100 : 0;
                    final isSelected = userAnswer == option;
                    return ListTile(
                      title: Text(option),
                      subtitle: LinearProgressIndicator(
                        value: percentage / 100,
                        color: Colors.green,
                        backgroundColor: Colors.grey[200],
                      ),
                      trailing: Text("${voteCount} votes"),
                      tileColor: isSelected ? Colors.green[50] : null,
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
