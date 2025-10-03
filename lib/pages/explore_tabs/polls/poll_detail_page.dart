import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PollDetailPage extends StatefulWidget {
  final String userId;
  final String activityId;
  final String title;
  final String description;
  final String sponsorName;
  final String sponsorLogo;
  final int pointsAwarded;
  final String rewardType;
  final List<Map<String, dynamic>> questions;

  const PollDetailPage({
    Key? key,
    required this.userId,
    required this.activityId,
    required this.title,
    required this.description,
    required this.sponsorName,
    required this.sponsorLogo,
    required this.pointsAwarded,
    required this.rewardType,
    required this.questions,
  }) : super(key: key);

  @override
  State<PollDetailPage> createState() => _PollDetailPageState();
}

class _PollDetailPageState extends State<PollDetailPage> {
  final Map<int, String> _answers = {};
  bool _isSubmitting = false;

  Future<void> _submitPoll() async {
    if (_answers.length < widget.questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please answer all questions")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);

      // 1️⃣ User poll attempts
      final pollAttemptRef = userRef.collection('poll_attempts').doc(widget.activityId);
      await pollAttemptRef.set({
        'activityId': widget.activityId,
        'activityTitle': widget.title,
        'description': widget.description,
        'sponsorName': widget.sponsorName,
        'rewardType': widget.rewardType,
        'rewardedItem': widget.pointsAwarded,
        'answers': _answers.map((k, v) => MapEntry(k.toString(), v)),
        'timestamp': FieldValue.serverTimestamp(),
        'userId': widget.userId,
        'rewarded': true,
      });

      // 2️⃣ Earned rewards
      final earnedRewardsRef = userRef.collection('rewards_earned').doc(widget.activityId);
      await earnedRewardsRef.set({
        'activityId': widget.activityId,
        'activityTitle': widget.title,
        'rewardType': widget.rewardType,
        'rewardedItem': widget.pointsAwarded,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3️⃣ Sponsor activity (sub)
      final sponsorPollRef = FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc('sub')
          .collection('poll')
          .doc(widget.activityId)
          .collection('users')
          .doc(widget.userId);

      await sponsorPollRef.set({
        'activityId': widget.activityId,
        'activityTitle': widget.title,
        'description': widget.description,
        'sponsorName': widget.sponsorName,
        'rewardType': widget.rewardType,
        'rewardedItem': widget.pointsAwarded,
        'answers': _answers.map((k, v) => MapEntry(k.toString(), v)),
        'timestamp': FieldValue.serverTimestamp(),
        'userId': widget.userId,
        'rewarded': true,
      });

      // 4️⃣ Sponsor activity (all/all_act)
      final sponsorAllRef = FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc('all')
          .collection('all_act')
          .doc(widget.activityId)
          .collection('users')
          .doc(widget.userId);

      await sponsorAllRef.set({
        'activityId': widget.activityId,
        'activityTitle': widget.title,
        'description': widget.description,
        'sponsorName': widget.sponsorName,
        'rewardType': widget.rewardType,
        'rewardedItem': widget.pointsAwarded,
        'answers': _answers.map((k, v) => MapEntry(k.toString(), v)),
        'timestamp': FieldValue.serverTimestamp(),
        'userId': widget.userId,
        'rewarded': true,
      });

      // Increment activities completed
      await userRef.update({'activitiesCompleted': FieldValue.increment(1)});

      // Navigate to analysis page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PollAnalysisPage(
            title: widget.title,
            rewardedItem: widget.pointsAwarded,
            rewardType: widget.rewardType,
          ),
        ),
      );
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.questions.length,
        itemBuilder: (context, index) {
          final question = widget.questions[index]['question'] as String? ?? 'Untitled Question';
          final options = List<String>.from(widget.questions[index]['options'] ?? []);

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...options.map((option) {
                    return RadioListTile<String>(
                      title: Text(option),
                      value: option,
                      groupValue: _answers[index],
                      onChanged: (val) => setState(() => _answers[index] = val!),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Submit Poll", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

/// ----------------------
/// Poll Analysis Page
/// ----------------------
class PollAnalysisPage extends StatelessWidget {
  final String title;
  final int rewardedItem;
  final String rewardType;

  const PollAnalysisPage({
    super.key,
    required this.title,
    required this.rewardedItem,
    required this.rewardType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Poll Completed"),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          color: Colors.green[50],
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                Text(
                  "✅ You completed the poll \"$title\"!",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "You have received $rewardedItem $rewardType",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Close"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
