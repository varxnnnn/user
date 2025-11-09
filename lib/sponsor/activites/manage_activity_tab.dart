import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'lucky_draw_participants_page.dart';

class ManageActivityTab extends StatefulWidget {
  const ManageActivityTab({super.key});

  @override
  State<ManageActivityTab> createState() => _ManageActivityTabState();
}

class _ManageActivityTabState extends State<ManageActivityTab> {
  String? sponsorId;

  @override
  void initState() {
    super.initState();
    loadSponsorId();
  }

  Future<void> loadSponsorId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      sponsorId = prefs.getString('sponsorId');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (sponsorId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("sponsor_activities")
          .where("sponsor_id", isEqualTo: sponsorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_note, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("No activities created yet.", style: TextStyle(fontSize: 16)),
                SizedBox(height: 8),
                Text("Create your first activity to get started!", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final allActivities = snapshot.data!.docs;
        
        // Sort activities by creation date (newest first) - client-side sorting
        final activities = allActivities.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['created_at'] as Timestamp?;
            final bTime = bData['created_at'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // Descending order
          });

        return ListView.builder(
          itemCount: activities.length,
          cacheExtent: 200,
          itemBuilder: (context, index) {
            final doc = activities[index];
            final data = doc.data() as Map<String, dynamic>;
            final activityId = doc.id;
            final title = data['title'] ?? 'Untitled Activity';
            final description = data['description'] ?? '';
            final type = data['type'] ?? 'unknown';
            final status = data['status'] ?? 'unknown';
            final createdAt = data['created_at'] as Timestamp?;
            final rewardAllocation = data['reward_allocation'] as Map<String, dynamic>?;
            final rules = data['rules'] as Map<String, dynamic>?;
            final targeting = data['targeting'] as Map<String, dynamic>?;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ExpansionTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(description, 
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Chip(
                          label: Text(type.toUpperCase(), style: const TextStyle(fontSize: 10)),
                          backgroundColor: _getTypeColor(type),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10)),
                          backgroundColor: _getStatusColor(status),
                        ),
                      ],
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow("Activity ID", activityId),
                        _buildInfoRow("Created", _formatDate(createdAt)),
                        if (rewardAllocation != null) ...[
                          _buildInfoRow("Reward ID", rewardAllocation['reward_id'] ?? 'N/A'),
                          _buildInfoRow("Allocated Qty", "${rewardAllocation['allocated_quantity'] ?? 0}"),
                          _buildInfoRow("Remaining Qty", "${rewardAllocation['remaining_quantity'] ?? 0}"),
                          if (rewardAllocation['assigned_item_ids'] != null) ...[
                            _buildInfoRow("Assigned Items", "${(rewardAllocation['assigned_item_ids'] as List).length} items"),
                            _buildInfoRow("Assigned At", _formatDate(rewardAllocation['assigned_at'] as Timestamp?)),
                          ],
                        ],
                        if (rules != null) ...[
                          _buildInfoRow("Attempts Allowed", "${rules['attempts_allowed'] ?? 1}"),
                        ],
                        if (targeting != null) ...[
                          _buildInfoRow("Age Range", "${targeting['min_age'] ?? 18}-${targeting['max_age'] ?? 60}"),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _editActivity(activityId, data),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text("Edit"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _viewActivityDetails(activityId, data),
                                icon: const Icon(Icons.visibility, size: 16),
                                label: const Text("View"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Show participants button for all activities
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _viewLuckyDrawParticipants(activityId, title, data),
                            icon: const Icon(Icons.people, size: 16),
                            label: Text(data['reward_distribution_type'] == 'lucky_draw' 
                                ? "View Participants & Select Winners" 
                                : "View Participants"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: data['reward_distribution_type'] == 'lucky_draw' 
                                  ? Colors.purple 
                                  : Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = timestamp.toDate();
      return DateFormat('MMM dd, yyyy - HH:mm').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'quiz':
        return Colors.blue.withOpacity(0.2);
      case 'poll':
        return Colors.green.withOpacity(0.2);
      case 'survey':
        return Colors.orange.withOpacity(0.2);
      case 'game':
        return Colors.purple.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green.withOpacity(0.2);
      case 'inactive':
        return Colors.red.withOpacity(0.2);
      case 'draft':
        return Colors.orange.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }

  void _editActivity(String activityId, Map<String, dynamic> activityData) {
    // TODO: Implement edit activity functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Edit activity: $activityId")),
    );
  }

  void _viewActivityDetails(String activityId, Map<String, dynamic> activityData) {
    // TODO: Implement view activity details functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activityData['title'] ?? 'Activity Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Description: ${activityData['description'] ?? 'N/A'}"),
              const SizedBox(height: 8),
              Text("Type: ${activityData['type'] ?? 'N/A'}"),
              Text("Status: ${activityData['status'] ?? 'N/A'}"),
              Text("Created: ${_formatDate(activityData['created_at'] as Timestamp?)}"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _viewLuckyDrawParticipants(String activityId, String activityTitle, Map<String, dynamic> activityData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LuckyDrawParticipantsPage(
          activityId: activityId,
          activityTitle: activityTitle,
          activityData: activityData,
        ),
      ),
    );
  }
}
