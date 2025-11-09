import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class AddYoutubeVideoPage extends StatefulWidget {
  final String title;
  final String description;
  final String type;
  final int minAge;
  final int maxAge;
  final String sponsorId;
  final String rewardId;
  final int allocatedQty;
  final int attemptsAllowed;
  final String? sponsorProfilePic;
  final String youtubeLink;
  final int timerDuration;
  final DateTime startDate;
  final DateTime endDate;
  final String rewardDistributionType;

  const AddYoutubeVideoPage({
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
    this.sponsorProfilePic,
    required this.youtubeLink,
    required this.timerDuration,
    required this.startDate,
    required this.endDate,
    required this.rewardDistributionType,
  });

  @override
  State<AddYoutubeVideoPage> createState() => _AddYoutubeVideoPageState();
}

class _AddYoutubeVideoPageState extends State<AddYoutubeVideoPage> {
  bool loading = false;

  Future<void> createActivity() async {
    setState(() => loading = true);

    try {
      final String activityId = const Uuid().v4();
      // Get sponsor details
      final sponsorDoc = await FirebaseFirestore.instance
          .collection('sponsors')
          .doc(widget.sponsorId)
          .get();
      
      final sponsorData = sponsorDoc.data() ?? {};

      final activityData = {
        "title": widget.title,
        "description": widget.description,
        "type": widget.type, // This will be "youtube" internally
        "sponsor_id": widget.sponsorId,
        "sponsor_details": {
          "name": sponsorData['name'],
          "profile_pic": sponsorData['profile_pic'],
          "contact_person": sponsorData['contact_person'],
          "email": sponsorData['email'],
          "phone": sponsorData['phone'],
        },
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
        "youtube_link": widget.youtubeLink,
        "timer_duration": widget.timerDuration,
      };

      // Save activity in main collection
      await FirebaseFirestore.instance.collection("sponsor_activities").doc(activityId).set(activityData);

      // Save under sponsor's subcollection
      final sponsorActivityRef = FirebaseFirestore.instance
          .collection("sponsors")
          .doc(widget.sponsorId)
          .collection("activities")
          .doc(activityId);

      await sponsorActivityRef.set(activityData);

      // Update reward available_quantity and assign reward items to activity
      final rewardRef = FirebaseFirestore.instance.collection('sponsor_rewards').doc(widget.rewardId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Read the current reward data first
        final snapshot = await transaction.get(rewardRef);
        
        if (!snapshot.exists) {
          throw Exception('Reward not found');
        }
        
        final currentQuantity = snapshot.data()?['available_quantity'] ?? 0;
        final newQuantity = currentQuantity - widget.allocatedQty;
        
        // Update the reward with new available quantity
        transaction.update(rewardRef, {
          "available_quantity": newQuantity < 0 ? 0 : newQuantity,
          "updated_at": FieldValue.serverTimestamp(),
        });
      });

      // Assign specific reward items to this activity
      await _assignRewardItemsToActivity(activityId, widget.rewardId, widget.allocatedQty);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Advertise Video Activity created successfully")));
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => loading = false);
  }

  Future<void> _assignRewardItemsToActivity(String activityId, String rewardId, int allocatedQty) async {
    try {
      // Get available reward items
      final rewardItemsQuery = await FirebaseFirestore.instance
          .collection('sponsor_rewards')
          .doc(rewardId)
          .collection('items')
          .where('status', isEqualTo: 'available') // Only get available items
          .limit(allocatedQty)
          .get();

      if (rewardItemsQuery.docs.length < allocatedQty) {
        throw Exception('Not enough available reward items. Available: ${rewardItemsQuery.docs.length}, Required: $allocatedQty');
      }

      // Update the selected items to assigned status
      final batch = FirebaseFirestore.instance.batch();
      
      for (final doc in rewardItemsQuery.docs) {
        batch.update(doc.reference, {
          'status': 'assigned',
          'activity_id': activityId,
          'assigned_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Also update the activity's reward allocation with the assigned item IDs
      final assignedItemIds = rewardItemsQuery.docs.map((doc) => doc.id).toList();
      
      await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(activityId)
          .update({
        'reward_allocation.assigned_item_ids': assignedItemIds,
        'reward_allocation.assigned_at': FieldValue.serverTimestamp(),
      });

      // Update sponsor's activity as well
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
      appBar: AppBar(title: const Text("Advertise Video Activity")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Advertise Video Details",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Activity Information", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text("Title: ${widget.title}"),
                    Text("Description: ${widget.description}"),
                    Text("Type: Advertise Video"),
                    Text("Age Range: ${widget.minAge} - ${widget.maxAge}"),
                    Text("Attempts Allowed: ${widget.attemptsAllowed}"),
                    Text("Start Date: ${widget.startDate.day}/${widget.startDate.month}/${widget.startDate.year}"),
                    Text("End Date: ${widget.endDate.day}/${widget.endDate.month}/${widget.endDate.year}"),
                    Text("Distribution Type: ${widget.rewardDistributionType == 'first_come_first_serve' ? 'First Come First Serve' : 'Lucky Draw'}"),
                    const SizedBox(height: 10),
                    const Text("Reward Information", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text("Allocated Quantity: ${widget.allocatedQty}"),
                    const SizedBox(height: 10),
                    const Text("YouTube Video", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text("Video Link: ${widget.youtubeLink}"),
                    Text("Timer Duration: ${widget.timerDuration} seconds"),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Text(
              "Note: This Advertise Video activity will allow users to watch the video for the specified duration. "
              "After completing the watch time, they will receive the allocated reward.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            
            const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : createActivity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Create Advertise Video Activity", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}