import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class AddPollQuestionsPage extends StatefulWidget {
  final String title;
  final String description;
  final String type;
  final int minAge;
  final int maxAge;
  final String sponsorId;
  final String rewardId;
  final int allocatedQty;
  final int attemptsAllowed;
  final DateTime startDate;
  final DateTime endDate;
  final String rewardDistributionType;

  const AddPollQuestionsPage({
    super.key,
    required this.title,
    required this.description,
    required this.type,
    required this.minAge,
    required this.maxAge,
    required this.sponsorId,
    required this.rewardId,
    required this.allocatedQty,
    required this.attemptsAllowed,
    required this.startDate,
    required this.endDate,
    required this.rewardDistributionType,
  });

  @override
  State<AddPollQuestionsPage> createState() => _AddPollQuestionsPageState();
}

class _AddPollQuestionsPageState extends State<AddPollQuestionsPage> {
  List<Map<String, dynamic>> pollQuestions = [];
  final TextEditingController questionController = TextEditingController();
  List<TextEditingController> optionControllers = [TextEditingController(), TextEditingController()];

  bool loading = false;

  void addOption() => setState(() => optionControllers.add(TextEditingController()));

  void removeOption(int index) {
    if (optionControllers.length <= 2) return;
    setState(() => optionControllers.removeAt(index));
  }

  void addPollQuestion() {
    if (questionController.text.trim().isEmpty ||
        optionControllers.any((c) => c.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    final pollData = {
      "question_text": questionController.text.trim(),
      "options": optionControllers.map((c) => c.text.trim()).toList(),
      "votes": List.filled(optionControllers.length, 0),
    };

    setState(() {
      pollQuestions.add(pollData);
      questionController.clear();
      optionControllers = [TextEditingController(), TextEditingController()];
    });
  }

  Future<void> createPollActivity() async {
    if (pollQuestions.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Add at least 1 poll question")));
      return;
    }

    setState(() => loading = true);

    try {
      final String activityId = const Uuid().v4();
      final activityData = {
        "title": widget.title,
        "description": widget.description,
        "type": widget.type,
        "sponsor_id": widget.sponsorId,
        "status": "active",
        "created_at": FieldValue.serverTimestamp(),
        "updated_at": FieldValue.serverTimestamp(),
        "start_date": widget.startDate,
        "end_date": widget.endDate,
        "reward_distribution_type": widget.rewardDistributionType,
        "rules": {"attempts_allowed": widget.attemptsAllowed},
        "targeting": {"min_age": widget.minAge, "max_age": widget.maxAge},
        "reward_allocation": {
          "reward_id": widget.rewardId,
          "allocated_quantity": widget.allocatedQty,
          "remaining_quantity": widget.allocatedQty,
        },
      };

      // 1️⃣ Save poll activity in main collection
      await FirebaseFirestore.instance
          .collection("sponsor_activities")
          .doc(activityId)
          .set(activityData);

      // 2️⃣ Save under sponsor's subcollection
      final sponsorActivityRef = FirebaseFirestore.instance
          .collection("sponsors")
          .doc(widget.sponsorId)
          .collection("activities")
          .doc(activityId);

      await sponsorActivityRef.set(activityData);

      // 3️⃣ Save poll questions
      final pollsRef = FirebaseFirestore.instance.collection("poll_questions");
      for (var q in pollQuestions) {
        final qId = const Uuid().v4();
        final qDataWithId = {
          ...q,
          "activity_id": activityId,
          "created_at": FieldValue.serverTimestamp(),
        };

        // Save globally
        await pollsRef.doc(qId).set(qDataWithId);

        // Save under activity
        await FirebaseFirestore.instance
            .collection("sponsor_activities")
            .doc(activityId)
            .collection("questions")
            .doc(qId)
            .set(qDataWithId);

        // Save under sponsor
        await sponsorActivityRef.collection("questions").doc(qId).set(qDataWithId);
      }

      // 4️⃣ Update reward available quantity
      final rewardRef =
      FirebaseFirestore.instance.collection('sponsor_rewards').doc(widget.rewardId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(rewardRef);
        if (!snapshot.exists) throw Exception('Reward not found');
        final currentQuantity = snapshot.data()?['available_quantity'] ?? 0;
        final newQuantity = currentQuantity - widget.allocatedQty;
        transaction.update(rewardRef, {
          "available_quantity": newQuantity < 0 ? 0 : newQuantity,
          "updated_at": FieldValue.serverTimestamp(),
        });
      });

      // 5️⃣ Assign reward items to activity
      await _assignRewardItemsToActivity(activityId, widget.rewardId, widget.allocatedQty);

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Poll activity created successfully")));
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => loading = false);
  }

  Future<void> _assignRewardItemsToActivity(
      String activityId, String rewardId, int allocatedQty) async {
    try {
      final rewardItemsQuery = await FirebaseFirestore.instance
          .collection('sponsor_rewards')
          .doc(rewardId)
          .collection('items')
          .where('status', isEqualTo: 'available')
          .limit(allocatedQty)
          .get();

      if (rewardItemsQuery.docs.length < allocatedQty) {
        throw Exception(
            'Not enough available reward items. Available: ${rewardItemsQuery.docs.length}, Required: $allocatedQty');
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in rewardItemsQuery.docs) {
        batch.update(doc.reference, {
          'status': 'assigned',
          'activity_id': activityId,
          'assigned_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      final assignedItemIds = rewardItemsQuery.docs.map((doc) => doc.id).toList();

      await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(activityId)
          .update({
        'reward_allocation.assigned_item_ids': assignedItemIds,
        'reward_allocation.assigned_at': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('sponsors')
          .doc(widget.sponsorId)
          .collection('activities')
          .doc(activityId)
          .update({
        'reward_allocation.assigned_item_ids': assignedItemIds,
        'reward_allocation.assigned_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error assigning reward items: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Step 3: Add Poll Questions")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: questionController,
              decoration: const InputDecoration(
                labelText: "Poll Question",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: optionControllers.length,
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: optionControllers[index],
                        decoration: InputDecoration(
                          labelText: "Option ${index + 1}",
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => removeOption(index),
                    ),
                  ],
                );
              },
            ),
            TextButton.icon(
              onPressed: addOption,
              icon: const Icon(Icons.add),
              label: const Text("Add Option"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: addPollQuestion,
              child: const Text("Add Poll Question to Activity"),
            ),
            const SizedBox(height: 20),
            const Text("Poll Questions Preview",
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...pollQuestions.map((q) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(q['question_text']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                      q['options'].length,
                          (i) =>
                          Text("${i + 1}. ${q['options'][i]} (Votes: 0)")),
                ),
              ),
            )),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : createPollActivity,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Create Poll Activity"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}