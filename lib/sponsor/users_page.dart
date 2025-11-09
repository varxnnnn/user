import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? sponsorId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSponsorId();
  }

  Future<void> _loadSponsorId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        sponsorId = prefs.getString('sponsorId');
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (sponsorId == null) {
      return const Center(child: Text('Error: Sponsor ID not found'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.list), text: 'Activity Details'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(sponsorId: sponsorId!),
          _ActivityDetailsTab(sponsorId: sponsorId!),
        ],
      ),
    );
  }
}

// Overview Tab - Shows summary statistics
class _OverviewTab extends StatelessWidget {
  final String sponsorId;

  const _OverviewTab({required this.sponsorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sponsor_activities')
          .where('sponsor_id', isEqualTo: sponsorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No activities created yet'),
              ],
            ),
          );
        }

        final activities = snapshot.data!.docs;
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            final activityData = activity.data() as Map<String, dynamic>;
            final activityId = activity.id;
            final activityTitle = activityData['title'] ?? 'Untitled';
            final activityType = activityData['type'] ?? 'unknown';
            final status = activityData['status'] ?? 'unknown';
            final rewardAllocation = activityData['reward_allocation'] as Map<String, dynamic>?;
            final allocatedQty = rewardAllocation?['allocated_quantity'] ?? 0;
            final remainingQty = rewardAllocation?['remaining_quantity'] ?? 0;

            return _ActivitySummaryCard(
              activityId: activityId,
              activityTitle: activityTitle,
              activityType: activityType,
              status: status,
              allocatedQty: allocatedQty,
              remainingQty: remainingQty,
            );
          },
        );
      },
    );
  }
}

class _ActivitySummaryCard extends StatelessWidget {
  final String activityId;
  final String activityTitle;
  final String activityType;
  final String status;
  final int allocatedQty;
  final int remainingQty;

  const _ActivitySummaryCard({
    required this.activityId,
    required this.activityTitle,
    required this.activityType,
    required this.status,
    required this.allocatedQty,
    required this.remainingQty,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('activity_participants')
          .where('activityId', isEqualTo: activityId)
          .get(),
      builder: (context, participantsSnapshot) {
        final totalParticipants = participantsSnapshot.data?.docs.length ?? 0;
        final rewardedCount = participantsSnapshot.data?.docs
            .where((doc) => (doc.data() as Map<String, dynamic>)['isRewarded'] == true)
            .length ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        activityTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _StatusChip(status: status),
                  ],
                ),
                const SizedBox(height: 8),
                _TypeChip(type: activityType),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        icon: Icons.people,
                        label: 'Participants',
                        value: '$totalParticipants',
                        color: Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.card_giftcard,
                        label: 'Rewarded',
                        value: '$rewardedCount',
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        icon: Icons.inventory,
                        label: 'Allocated',
                        value: '$allocatedQty',
                        color: Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.inventory_2,
                        label: 'Remaining',
                        value: '$remainingQty',
                        color: Colors.purple,
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
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
        color = Colors.green;
        break;
      case 'inactive':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (type.toLowerCase()) {
      case 'quiz':
        color = Colors.blue;
        break;
      case 'poll':
        color = Colors.green;
        break;
      case 'survey':
        color = Colors.orange;
        break;
      case 'youtube':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Activity Details Tab - Shows detailed participant information
class _ActivityDetailsTab extends StatefulWidget {
  final String sponsorId;

  const _ActivityDetailsTab({required this.sponsorId});

  @override
  State<_ActivityDetailsTab> createState() => _ActivityDetailsTabState();
}

class _ActivityDetailsTabState extends State<_ActivityDetailsTab> {
  String? selectedActivityId;
  String searchQuery = '';
  String filterStatus = 'all'; // all, rewarded, pending

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Activity Selector
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sponsor_activities')
              .where('sponsor_id', isEqualTo: widget.sponsorId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No activities available'),
              );
            }

            final activities = snapshot.data!.docs;
            
            return Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedActivityId,
                    hint: const Text('Select an activity'),
                    decoration: const InputDecoration(
                      labelText: 'Activity',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: activities.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(data['title'] ?? 'Untitled'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedActivityId = value;
                      });
                    },
                  ),
                  if (selectedActivityId != null) ...[
                    const SizedBox(height: 12),
                    // Filter chips
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('All'),
                            selected: filterStatus == 'all',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => filterStatus = 'all');
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Rewarded'),
                            selected: filterStatus == 'rewarded',
                            selectedColor: Colors.green.shade100,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => filterStatus = 'rewarded');
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Pending'),
                            selected: filterStatus == 'pending',
                            selectedColor: Colors.orange.shade100,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => filterStatus = 'pending');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search bar
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by user name or email',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) {
                        setState(() => searchQuery = value.toLowerCase());
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),

        // Participants List
        if (selectedActivityId != null)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('activity_participants')
                  .where('activityId', isEqualTo: selectedActivityId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No participants yet'),
                      ],
                    ),
                  );
                }

                var participants = snapshot.data!.docs;

                // Apply filters
                if (filterStatus != 'all') {
                  participants = participants.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isRewarded = data['isRewarded'] == true;
                    if (filterStatus == 'rewarded') {
                      return isRewarded;
                    } else {
                      return !isRewarded;
                    }
                  }).toList();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final participantDoc = participants[index];
                    final participantData = participantDoc.data() as Map<String, dynamic>;
                    final userId = participantData['userId'] as String;

                    return _ParticipantCard(
                      userId: userId,
                      activityId: selectedActivityId!,
                      participantData: participantData,
                      searchQuery: searchQuery,
                    );
                  },
                );
              },
            ),
          )
        else
          const Expanded(
            child: Center(
              child: Text('Select an activity to view participants'),
            ),
          ),
      ],
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  final String userId;
  final String activityId;
  final Map<String, dynamic> participantData;
  final String searchQuery;

  const _ParticipantCard({
    required this.userId,
    required this.activityId,
    required this.participantData,
    required this.searchQuery,
  });

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = timestamp.toDate();
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const SizedBox();
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox();

        final userName = userData['name'] ?? 'Unknown User';
        final userEmail = userData['email'] ?? '';

        // Apply search filter
        if (searchQuery.isNotEmpty) {
          if (!userName.toLowerCase().contains(searchQuery) &&
              !userEmail.toLowerCase().contains(searchQuery)) {
            return const SizedBox();
          }
        }

        final isRewarded = participantData['isRewarded'] == true;
        final activityType = participantData['activityType'] ?? 'unknown';
        final completedAt = participantData['completedAt'] as Timestamp?;
        final score = participantData['score'];
        final totalQuestions = participantData['totalQuestions'];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: isRewarded ? Colors.green : Colors.orange,
              child: Icon(
                isRewarded ? Icons.check_circle : Icons.pending,
                color: Colors.white,
              ),
            ),
            title: Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userEmail),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _TypeChip(type: activityType),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isRewarded ? Colors.green.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isRewarded ? 'REWARDED' : 'PENDING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isRewarded ? Colors.green.shade800 : Colors.orange.shade800,
                        ),
                      ),
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
                    _InfoRow('User ID', userId),
                    if (score != null && totalQuestions != null)
                      _InfoRow('Score', '$score / $totalQuestions'),
                    _InfoRow('Completed At', _formatDate(completedAt)),
                    if (isRewarded) ...[
                      const Divider(),
                      const Text(
                        'Reward Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _InfoRow('Reward Code', participantData['rewardCode']?.toString() ?? 'N/A'),
                      _InfoRow('Rewarded At', _formatDate(participantData['rewardedAt'] as Timestamp?)),
                    ] else ...[
                      const Divider(),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade800),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Reward has not been assigned yet. For lucky draw activities, select winners from the Activity tab.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
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
}
