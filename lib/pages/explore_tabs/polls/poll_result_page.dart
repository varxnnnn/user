import 'package:flutter/material.dart';

class PollResultPage extends StatelessWidget {
  final String title;
  final String sponsorName;
  final String sponsorProfilePic;
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
    required this.sponsorName,
    required this.sponsorProfilePic,
    required this.questions,
    required this.answers,
    required this.rewardedItem,
    required this.rewardType,
    this.rewardCode,
    this.rewardTitle,
    this.rewardDescription,
  });

  String _getRewardDisplayText() {
    switch (rewardType.toLowerCase()) {
      case 'points':
        return "Reward: $rewardedItem points";
      case 'voucher':
        return "Reward: ${rewardTitle ?? 'Voucher'} (Code: ${rewardCode ?? 'N/A'})";
      case 'product':
      case 'products':
        return "Reward: ${rewardTitle ?? 'Product'} (Code: ${rewardCode ?? 'N/A'})";
      default:
        return "Reward: ${rewardTitle ?? 'Reward'} ($rewardedItem points)";
    }
  }

  String _getSuccessMessage() {
    switch (rewardType.toLowerCase()) {
      case 'points':
        return "Thank you for participating! You earned $rewardedItem points!";
      case 'voucher':
        return "Thank you! You received a ${rewardTitle ?? 'voucher'}! Check your redemptions.";
      case 'product':
      case 'products':
        return "Thank you! You received a ${rewardTitle ?? 'product'}! Check your redemptions.";
      default:
        return "Thank you for participating! You earned a reward!";
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.orange.shade700,
          backgroundImage: sponsorProfilePic.isNotEmpty ? NetworkImage(sponsorProfilePic) : null,
          child: sponsorProfilePic.isEmpty
              ? Text(
                  sponsorName.isNotEmpty ? sponsorName[0].toUpperCase() : 'S',
                  style: const TextStyle(color: Colors.white),
                )
              : null,
          onBackgroundImageError: (exception, stackTrace) {
            debugPrint('Failed to load sponsor profile pic: $exception');
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sponsorName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_getRewardDisplayText()),
              Text(title, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysis(BuildContext context) {
    return ListView.builder(
      itemCount: questions.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Card(
            color: Colors.orange.shade50,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.how_to_vote,
                        color: Colors.orange.shade700,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Poll Completed!",
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _getSuccessMessage(),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.orange.shade200,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.question_answer,
                      color: Colors.orange.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${index}. ${q['question_text']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(options.length, (i) {
                  final option = options[i];
                  final voteCount = votes[i];
                  final percentage = totalVotes > 0 ? (voteCount / totalVotes) * 100 : 0;
                  final isSelected = userAnswer == option;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.orange.shade700 : Colors.grey.shade300,
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              option,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? Colors.orange.shade700 : null,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "${percentage.toStringAsFixed(1)}%",
                              style: TextStyle(
                                color: isSelected ? Colors.orange.shade700 : Colors.grey.shade600,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isSelected ? Colors.orange.shade700 : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$voteCount ${voteCount == 1 ? 'vote' : 'votes'}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
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
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.home),
            label: const Text("Back to Home"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text("Back to Poll"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade700,
              side: BorderSide(color: Colors.orange.shade700),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Poll Results"),
        centerTitle: true,
        backgroundColor: Colors.orange.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(child: _buildAnalysis(context)),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }
}