import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ManageMilestoneTab extends StatefulWidget {
  const ManageMilestoneTab({super.key});

  @override
  _ManageMilestoneTabState createState() => _ManageMilestoneTabState();
}

class _ManageMilestoneTabState extends State<ManageMilestoneTab> {
  String? sponsorId;
  String currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadSponsorId();
  }

  Future<void> _loadSponsorId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      sponsorId = prefs.getString('sponsorId');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (sponsorId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).primaryColor,
            child: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'Current Month Milestones'),
                Tab(text: 'All Milestones'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCurrentMonthMilestones(),
                _buildAllMilestones(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentMonthMilestones() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('milestones')
          .where('month', isEqualTo: currentMonth)
          .where('createdBy', isEqualTo: sponsorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.flag_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No milestones created for $currentMonth.',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Click "Create Milestone" tab to create one.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Sort by createdAt descending client-side
        final sortedDocs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aCreated = aData['createdAt'] as Timestamp?;
            final bCreated = bData['createdAt'] as Timestamp?;
            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;
            return bCreated.compareTo(aCreated);
          });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            return _buildMilestoneCard(doc);
          },
        );
      },
    );
  }

  Widget _buildAllMilestones() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('milestones')
          .where('createdBy', isEqualTo: sponsorId)
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
            child: Text('No milestones found'),
          );
        }

        // Sort by createdAt descending client-side
        final sortedDocs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aCreated = aData['createdAt'] as Timestamp?;
            final bCreated = bData['createdAt'] as Timestamp?;
            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;
            return bCreated.compareTo(aCreated);
          });

        // Group by month
        final Map<String, List<DocumentSnapshot>> grouped = {};
        for (var doc in sortedDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final month = data['month'] as String? ?? 'Unknown';
          grouped.putIfAbsent(month, () => []);
          grouped[month]!.add(doc);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final month = grouped.keys.elementAt(index);
            final milestones = grouped[month]!;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    month,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...milestones.map((doc) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildMilestoneCard(doc),
                    )).toList(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMilestoneCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final milestoneId = doc.id;
    final title = data['title'] ?? 'Untitled';
    final month = data['month'] ?? 'Unknown';
    final reward = data['reward'] ?? 10;
    final status = data['status'] ?? 'active';
    final createdAt = data['createdAt'] as Timestamp?;
    final updatedAt = data['updatedAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'active' ? Colors.green : Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Available for all users',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Month', month),
                _buildInfoRow('Reward per Level', '$reward coins'),
                if (createdAt != null)
                  _buildInfoRow(
                    'Created',
                    DateFormat('MMM dd, yyyy HH:mm').format(createdAt.toDate()),
                  ),
                const SizedBox(height: 12),
                // Levels List
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('milestones')
                      .doc(milestoneId)
                      .collection('levels')
                      .orderBy('level_number')
                      .snapshots(),
                  builder: (context, levelsSnapshot) {
                    if (levelsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!levelsSnapshot.hasData || levelsSnapshot.data!.docs.isEmpty) {
                      return const Text('No levels found');
                    }

                    final levels = levelsSnapshot.data!.docs;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Levels:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...levels.map((levelDoc) {
                          final levelData = levelDoc.data() as Map<String, dynamic>;
                          final levelNumber = levelData['level_number'] ?? 0;
                          final description = levelData['description'] ?? '';
                          final taskCount = levelData['task_count'] ?? 0;
                          final levelReward = levelData['reward'] ?? reward;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$levelNumber',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    description,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '+$levelReward coins',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _toggleMilestoneStatus(milestoneId, status),
                        icon: Icon(status == 'active' ? Icons.pause : Icons.play_arrow),
                        label: Text(status == 'active' ? 'Deactivate' : 'Activate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: status == 'active' ? Colors.orange : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _deleteMilestone(milestoneId),
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMilestoneStatus(String milestoneId, String currentStatus) async {
    try {
      final newStatus = currentStatus == 'active' ? 'inactive' : 'active';
      
      await FirebaseFirestore.instance
          .collection('milestones')
          .doc(milestoneId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Milestone ${newStatus == 'active' ? 'activated' : 'deactivated'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating milestone: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMilestone(String milestoneId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Milestone'),
        content: const Text(
          'Are you sure you want to delete this milestone? '
          'This will also delete all associated levels and user progress. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete all levels in this milestone
      final levelsSnapshot = await FirebaseFirestore.instance
          .collection('milestones')
          .doc(milestoneId)
          .collection('levels')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      
      for (var levelDoc in levelsSnapshot.docs) {
        batch.delete(levelDoc.reference);
      }

      // Delete all user progress for this milestone
      final progressSnapshot = await FirebaseFirestore.instance
          .collection('milestones')
          .doc(milestoneId)
          .collection('user_progress')
          .get();

      for (var progressDoc in progressSnapshot.docs) {
        batch.delete(progressDoc.reference);
      }

      // Delete the milestone itself
      batch.delete(
        FirebaseFirestore.instance.collection('milestones').doc(milestoneId),
      );

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Milestone deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting milestone: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

