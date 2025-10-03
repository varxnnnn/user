import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SurveyDetailPage extends StatefulWidget {
  final String userId;
  final String activityId;
  final String title;
  final String description;
  final String sponsorName;
  final String sponsorLogo;
  final String rewardType;
  final dynamic rewardedItem;
  final List<Map<String, dynamic>> questions;

  const SurveyDetailPage({
    super.key,
    required this.userId,
    required this.activityId,
    required this.title,
    required this.description,
    required this.sponsorName,
    required this.sponsorLogo,
    required this.rewardType,
    required this.rewardedItem,
    required this.questions,
    required pointsAwarded,
  });

  @override
  State<SurveyDetailPage> createState() => _SurveyDetailPageState();
}

class _SurveyDetailPageState extends State<SurveyDetailPage> {
  late List<String?> _answers;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _answers = List<String?>.filled(widget.questions.length, null);
    _checkAlreadySubmitted();
  }

  Future<void> _checkAlreadySubmitted() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('survey_attempts')
        .doc(widget.activityId)
        .get();

    if (doc.exists) {
      final savedAnswers = List<String>.from(doc.data()?['answers'] ?? []);
      setState(() {
        _answers = savedAnswers;
        _submitted = true;
      });
      _navigateToAnalysis();
    }
  }

  Future<void> _submitSurvey() async {
    if (_answers.any((ans) => ans == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please answer all questions.")));
      return;
    }

    final attemptData = {
      'activityId': widget.activityId,
      'activityTitle': widget.title,
      'description': widget.description,
      'sponsorName': widget.sponsorName,
      'rewardType': widget.rewardType,
      'rewardedItem': widget.rewardedItem,
      'answers': _answers,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': widget.userId,
      'rewarded': true,
    };

    try {
      // Save under user's survey_attempts
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('survey_attempts')
          .doc(widget.activityId)
          .set(attemptData);

      // Save under sponsor activities sub collection
      await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc('sub')
          .collection('survey')
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

      // Update user's activitiesCompleted count
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

      setState(() {
        _submitted = true;
      });

      _navigateToAnalysis();
    } catch (e) {
      debugPrint("Error saving survey attempt: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error submitting survey: $e")));
    }
  }

  void _navigateToAnalysis() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SurveyAnalysisPage(
          title: widget.title,
          rewardedItem: widget.rewardedItem,
          rewardType: widget.rewardType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.orange,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(child: _buildQuestions()),
            if (!_submitted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitSurvey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Submit Survey",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          backgroundImage: widget.sponsorLogo.isNotEmpty
              ? NetworkImage(widget.sponsorLogo)
              : null,
          child: widget.sponsorLogo.isEmpty
              ? Text(widget.sponsorName[0].toUpperCase())
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.sponsorName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(widget.description,
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestions() {
    return ListView.builder(
      itemCount: widget.questions.length,
      itemBuilder: (context, index) {
        final q = widget.questions[index];
        final options = List<String>.from(q['options'] ?? []);

        // Hide the last option
        final visibleOptions = options.length > 1
            ? options.sublist(0, options.length - 1)
            : options;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${index + 1}. ${q['question']}",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...visibleOptions.map((opt) => RadioListTile<String>(
                  title: Text(opt),
                  value: opt,
                  groupValue: _answers[index],
                  onChanged: _submitted
                      ? null
                      : (val) => setState(() => _answers[index] = val),
                )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SurveyAnalysisPage extends StatelessWidget {
  final dynamic rewardedItem;
  final String rewardType;
  final String title;

  const SurveyAnalysisPage({
    super.key,
    required this.rewardedItem,
    required this.rewardType,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Survey Completed"),
        backgroundColor: Colors.green,
        centerTitle: true,
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
                const Icon(Icons.check_circle,
                    color: Colors.green, size: 64),
                const SizedBox(height: 16),
                Text(
                  "✅ You completed the survey \"$title\"!",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
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
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
