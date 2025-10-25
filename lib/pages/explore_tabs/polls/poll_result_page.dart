import 'package:flutter/material.dart';

class PollResultPage extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> questions;
  final Map<int, String> answers;
  final int rewardedItem;
  final String rewardType;
  final String? rewardCode;
  final String? rewardTitle;
  final String? rewardDescription;

  const PollResultPage({
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
                    if (rewardCode != null || rewardTitle != null || rewardDescription != null) ...[
                      const SizedBox(height: 8),
                      if (rewardTitle != null)
                        Text(rewardTitle!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (rewardDescription != null)
                        Text(rewardDescription!),
                      if (rewardCode != null)
                        Text("Code: $rewardCode", style: const TextStyle(fontFamily: 'monospace')),
                    ],
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