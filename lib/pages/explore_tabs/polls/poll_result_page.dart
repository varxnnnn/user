import 'package:flutter/material.dart';

class PollResultPage extends StatelessWidget {
  final String activityId;
  final String title;
  final String description;
  final String sponsorName;
  final String sponsorLogo;
  final String rewardType;
  final int rewardedItem;
  final List<Map<String, dynamic>> questions; // question_text, options, votes
  final Map<int, String> answers;
  final String userId;

  const PollResultPage({
    super.key,
    required this.activityId,
    required this.title,
    required this.description,
    required this.sponsorName,
    required this.sponsorLogo,
    required this.rewardType,
    required this.rewardedItem,
    required this.questions,
    required this.answers,
    required this.userId,
  });

  String _getRewardDisplayText() {
    if (rewardedItem <= 0) return "No reward";
    switch (rewardType.toLowerCase()) {
      case 'points':
        return "Reward: $rewardedItem points";
      case 'voucher':
        return "Reward: Voucher ($rewardedItem)";
      default:
        return "Reward: $rewardedItem $rewardType";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Poll Completed"),
        centerTitle: true,
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(child: _buildPollAnalysis()),
            _buildActionButtons(context),
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
          backgroundColor: Colors.green,
          child: Text(
            sponsorName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sponsorName, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(_getRewardDisplayText()),
              Text(title, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPollAnalysis() {
    return ListView.builder(
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final q = questions[index];
        final selected = answers[index];
        final options = List<String>.from(q['options'] ?? []);
        final votes = List<int>.from(q['votes'] ?? List.filled(options.length, 0));
        final totalVotes = votes.fold(0, (sum, v) => sum + v);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${index + 1}. ${q['question_text']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                ...List.generate(options.length, (i) {
                  final option = options[i];
                  final voteCount = votes[i];
                  final percentage = totalVotes > 0 ? (voteCount / totalVotes * 100).toStringAsFixed(1) : "0.0";
                  final isSelected = option == selected;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green[100] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? Colors.green : Colors.grey),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(option, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        Text("$voteCount votes ($percentage%)"),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home),
            label: const Text("Back to Home"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text("Back to Poll"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
