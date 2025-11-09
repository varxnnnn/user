import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_questions_page.dart';
import 'poll_question_page.dart'; // NEW import
import 'survey_questions_page.dart'; // NEW import
import 'youtube_video_page.dart'; // NEW import

class SelectRewardPage extends StatefulWidget {
  final String title;
  final String description;
  final String type;
  final int minAge;
  final int maxAge;
  final String sponsorId;
  final int attemptsAllowed;
  final String? sponsorProfilePic;
  final DateTime startDate;
  final DateTime endDate;
  final String rewardDistributionType;

  const SelectRewardPage({
    super.key,
    required this.title,
    required this.description,
    required this.type,
    required this.minAge,
    required this.maxAge,
    required this.sponsorId,
    required this.attemptsAllowed,
    this.sponsorProfilePic,
    required this.startDate,
    required this.endDate,
    required this.rewardDistributionType,
  });

  @override
  State<SelectRewardPage> createState() => _SelectRewardPageState();
}

class _SelectRewardPageState extends State<SelectRewardPage> {
  String? selectedRewardId;
  int allocatedQty = 0;
  Map<String, dynamic>? selectedReward;
  final TextEditingController _quantityController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Step 2: Select Reward")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sponsor_rewards')
            .where('sponsor_id', isEqualTo: widget.sponsorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No rewards available"));
          }

          final allRewards = snapshot.data!.docs;

          final rewards = allRewards.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] == 'active';
          }).toList()
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['created_at'] as Timestamp?;
              final bTime = bData['created_at'] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: rewards.length,
                  itemBuilder: (context, index) {
                    final rewardDoc = rewards[index];
                    final data = rewardDoc.data() as Map<String, dynamic>;
                    final availableStock = data['available_quantity'] ?? 0;
                    final rewardTitle = data['title'] ?? 'Untitled Reward';
                    final rewardType = data['type'] ?? 'unknown';
                    final description = data['description'] ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: RadioListTile<String>(
                        title: Text(
                          "$rewardTitle ($rewardType)",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Available Stock: $availableStock"),
                            if (description.isNotEmpty)
                              Text(
                                description,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        value: rewardDoc.id,
                        groupValue: selectedRewardId,
                        onChanged: availableStock > 0
                            ? (val) {
                                setState(() {
                                  selectedRewardId = val;
                                  selectedReward = data;
                                  allocatedQty = 1;
                                  _quantityController.text = '1';
                                });
                              }
                            : null,
                      ),
                    );
                  },
                ),
              ),
              if (selectedReward != null) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Selected Reward: ${selectedReward!['title']}",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _quantityController,
                        decoration: InputDecoration(
                          labelText:
                              "Allocate Quantity (max ${selectedReward!['available_quantity'] ?? 0})",
                          border: const OutlineInputBorder(),
                          helperText: "Enter quantity to allocate for this activity",
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          final qty = int.tryParse(val) ?? 0;
                          final maxQty = selectedReward!['available_quantity'] ?? 0;
                          setState(() {
                            allocatedQty = qty.clamp(0, maxQty).toInt();
                            if (qty > maxQty) {
                              _quantityController.text = maxQty.toString();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: allocatedQty <= 0 ||
                              allocatedQty > (selectedReward!['available_quantity'] ?? 0)
                              ? null
                              : () {
                            if (widget.type == "poll") {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddPollQuestionsPage(
                                    title: widget.title,
                                    description: widget.description,
                                    type: widget.type,
                                    minAge: widget.minAge,
                                    maxAge: widget.maxAge,
                                    sponsorId: widget.sponsorId,
                                    rewardId: selectedRewardId!,
                                    allocatedQty: allocatedQty,
                                    attemptsAllowed: widget.attemptsAllowed,
                                    startDate: widget.startDate,
                                    endDate: widget.endDate,
                                    rewardDistributionType: widget.rewardDistributionType,
                                  ),
                                ),
                              );
                            } else if (widget.type == "survey") {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddSurveyQuestionsPage(
                                    title: widget.title,
                                    description: widget.description,
                                    type: widget.type,
                                    minAge: widget.minAge,
                                    maxAge: widget.maxAge,
                                    sponsorId: widget.sponsorId,
                                    rewardId: selectedRewardId!,
                                    allocatedQty: allocatedQty,
                                    attemptsAllowed: widget.attemptsAllowed,
                                    startDate: widget.startDate,
                                    endDate: widget.endDate,
                                    rewardDistributionType: widget.rewardDistributionType,
                                  ),
                                ),
                              );
                            } else if (widget.type == "advertise_video") {
                              // For Advertise Video, we need to collect the video link and timer
                              _showYoutubeInputDialog(context);
                            } else {
                              // Default to quiz
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddQuestionsPage(
                                    title: widget.title,
                                    description: widget.description,
                                    type: widget.type,
                                    minAge: widget.minAge,
                                    maxAge: widget.maxAge,
                                    sponsorId: widget.sponsorId,
                                    rewardId: selectedRewardId!,
                                    allocatedQty: allocatedQty,
                                    attemptsAllowed: widget.attemptsAllowed,
                                    sponsorProfilePic: widget.sponsorProfilePic,
                                    startDate: widget.startDate,
                                    endDate: widget.endDate,
                                    rewardDistributionType: widget.rewardDistributionType,
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text("Next"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showYoutubeInputDialog(BuildContext context) {
    final TextEditingController linkController = TextEditingController();
    final TextEditingController timerController = TextEditingController(text: "60");

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Advertise Video Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: linkController,
                decoration: const InputDecoration(
                  labelText: "YouTube Video Link",
                  hintText: "https://www.youtube.com/watch?v=...",
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: timerController,
                decoration: const InputDecoration(
                  labelText: "Timer Duration (seconds)",
                  hintText: "60",
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (linkController.text.isEmpty || timerController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please fill all fields")),
                  );
                  return;
                }
                
                final timerDuration = int.tryParse(timerController.text) ?? 60;
                
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddYoutubeVideoPage(
                      title: widget.title,
                      description: widget.description,
                      type: "youtube", // Keep the internal type as "youtube"
                      minAge: widget.minAge,
                      maxAge: widget.maxAge,
                      sponsorId: widget.sponsorId,
                      rewardId: selectedRewardId!,
                      allocatedQty: allocatedQty,
                      attemptsAllowed: widget.attemptsAllowed,
                      sponsorProfilePic: widget.sponsorProfilePic,
                      youtubeLink: linkController.text.trim(),
                      timerDuration: timerDuration,
                      startDate: widget.startDate,
                      endDate: widget.endDate,
                      rewardDistributionType: widget.rewardDistributionType,
                    ),
                  ),
                );
              },
              child: const Text("Continue"),
            ),
          ],
        );
      },
    );
  }
}