import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class MilestoneStatisticsTab extends StatefulWidget {
  const MilestoneStatisticsTab({super.key});

  @override
  _MilestoneStatisticsTabState createState() => _MilestoneStatisticsTabState();
}

class _MilestoneStatisticsTabState extends State<MilestoneStatisticsTab> {
  String? sponsorId;
  String? selectedMilestoneId;
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Milestone Statistics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Milestone selector
          _buildMilestoneSelector(),
          const SizedBox(height: 24),
          
          if (selectedMilestoneId != null) ...[
            _buildOverallStats(),
            const SizedBox(height: 24),
            _buildLevelStats(),
            const SizedBox(height: 24),
            _buildTopUsers(),
          ],
        ],
      ),
    );
  }

  Widget _buildMilestoneSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('milestones')
          .where('createdBy', isEqualTo: sponsorId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No active milestones found'),
            ),
          );
        }

        final milestones = snapshot.data!.docs;

        // Auto-select current month milestone if not selected
        if (selectedMilestoneId == null) {
          final currentMonthMilestone = milestones.firstWhere(
            (doc) => (doc.data() as Map<String, dynamic>)['month'] == currentMonth,
            orElse: () => milestones.first,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              selectedMilestoneId = currentMonthMilestone.id;
            });
          });
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Milestone',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  isExpanded: true,
                  value: selectedMilestoneId,
                  items: milestones.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text('${data['title']} - ${data['month']}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedMilestoneId = value;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverallStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('milestones')
          .doc(selectedMilestoneId)
          .collection('user_progress')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final userProgressDocs = snapshot.data!.docs;
        final totalUsers = userProgressDocs.length;
        int totalLevelsClaimed = 0;

        for (var doc in userProgressDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final completedLevels = data['completed_level_ids'] as List<dynamic>?;
          totalLevelsClaimed += completedLevels?.length ?? 0;
        }

        return Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Participants',
                        totalUsers.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Total Levels Claimed',
                        totalLevelsClaimed.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('milestones')
          .doc(selectedMilestoneId)
          .collection('levels')
          .orderBy('level_number')
          .snapshots(),
      builder: (context, levelsSnapshot) {
        if (!levelsSnapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('milestones')
              .doc(selectedMilestoneId)
              .collection('user_progress')
              .snapshots(),
          builder: (context, progressSnapshot) {
            if (!progressSnapshot.hasData) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final levels = levelsSnapshot.data!.docs;
            final userProgressDocs = progressSnapshot.data!.docs;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Level Completion Statistics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...levels.map((levelDoc) {
                      final levelData = levelDoc.data() as Map<String, dynamic>;
                      final levelId = levelDoc.id;
                      final levelNumber = levelData['level_number'] ?? 0;
                      final description = levelData['description'] ?? '';
                      
                      int claimedCount = 0;
                      for (var progressDoc in userProgressDocs) {
                        final progressData = progressDoc.data() as Map<String, dynamic>;
                        final completedLevels = progressData['completed_level_ids'] as List<dynamic>?;
                        if (completedLevels?.contains(levelId) == true) {
                          claimedCount++;
                        }
                      }

                      final percentage = userProgressDocs.isEmpty 
                          ? 0.0 
                          : (claimedCount / userProgressDocs.length) * 100;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$claimedCount users',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                minHeight: 8,
                                backgroundColor: Colors.grey[300],
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${percentage.toStringAsFixed(1)}% completion rate',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopUsers() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('milestones')
          .doc(selectedMilestoneId)
          .collection('user_progress')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No user progress data available'),
            ),
          );
        }

        final userProgressDocs = snapshot.data!.docs;
        
        // Sort users by number of completed levels
        final sortedUsers = userProgressDocs.toList()..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCompleted = (aData['completed_level_ids'] as List<dynamic>?)?.length ?? 0;
          final bCompleted = (bData['completed_level_ids'] as List<dynamic>?)?.length ?? 0;
          return bCompleted.compareTo(aCompleted);
        });

        final topUsers = sortedUsers.take(10).toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top 10 Users',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...topUsers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final doc = entry.value;
                  final userId = doc.id;
                  final data = doc.data() as Map<String, dynamic>;
                  final completedLevels = (data['completed_level_ids'] as List<dynamic>?)?.length ?? 0;

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                    builder: (context, userSnapshot) {
                      final userName = userSnapshot.hasData 
                          ? ((userSnapshot.data!.data() as Map<String, dynamic>?)?['name'] ?? 'User $userId')
                          : 'Loading...';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: index < 3 
                              ? Colors.orange.shade50 
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: index < 3 
                              ? Border.all(color: Colors.orange, width: 2)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: index == 0 
                                    ? Colors.amber 
                                    : (index == 1 ? Colors.grey : Colors.brown),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$completedLevels levels',
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
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }
}
