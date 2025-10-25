import 'package:flutter/material.dart';

class SurveyResultPage extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> questions;
  final Map<int, dynamic> answers;
  final int rewardedItem;
  final String rewardType;
  final String? rewardCode;
  final String? rewardTitle;
  final String? rewardDescription;

  const SurveyResultPage({
    super.key,
    required this.title,
    required this.questions,
    required this.answers,
    required this.rewardedItem,
    required this.rewardType,
    this.rewardCode,
    this.rewardTitle,
    this.rewardDescription,
  });

  @override
  State<SurveyResultPage> createState() => _SurveyResultPageState();
}

class _SurveyResultPageState extends State<SurveyResultPage> {
  @override
  void initState() {
    super.initState();
    // Auto-close after 2.5 seconds and signal success
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pop(true); // returns true to caller
      }
    });
  }

  Widget _buildAnswerDisplay(Map<String, dynamic> q, dynamic answer) {
    final type = q['question_type'];
    switch (type) {
      case 'short':
        return Text("Your Answer: ${answer ?? 'Not answered'}");
      case 'rating':
        return Text("Your Rating: ${answer ?? 'Not answered'}");
      case 'mcq':
        final options = List<String>.from(q['options']);
        // Note: surveys don't store 'votes' like polls — so we skip progress bars
        // If you DO store votes, keep this logic. Otherwise, simplify.
        return Text("Your Answer: $answer");
      default:
        return Text("Answer: $answer (Unsupported type: $type)");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Survey Results"),
        backgroundColor: Colors.green,
        automaticallyImplyLeading: false, // Hide back button since auto-closing
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.questions.length + 1,
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
                    Text(
                      "✅ You completed the survey \"${widget.title}\"!",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "You have received ${widget.rewardedItem} ${widget.rewardType}",
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (widget.rewardCode != null ||
                        widget.rewardTitle != null ||
                        widget.rewardDescription != null) ...[
                      const SizedBox(height: 8),
                      if (widget.rewardTitle != null)
                        Text(widget.rewardTitle!,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (widget.rewardDescription != null)
                        Text(widget.rewardDescription!),
                      if (widget.rewardCode != null)
                        Text("Code: ${widget.rewardCode}",
                            style: const TextStyle(fontFamily: 'monospace')),
                    ],
                  ],
                ),
              ),
            );
          }

          final q = widget.questions[index - 1];
          final answer = widget.answers[index - 1];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildAnswerDisplay(q, answer),
            ),
          );
        },
      ),
    );
  }
}