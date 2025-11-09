import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RewardHistoryWidget extends StatelessWidget {
  const RewardHistoryWidget({Key? key}) : super(key: key);

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = timestamp.toDate();
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'claimed':
        return Colors.green;
      case 'issued':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'not_selected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status, String? rewardStatus) {
    // For lucky draw activities
    if (rewardStatus == 'pending') {
      return 'In Progress - Awaiting Selection';
    } else if (rewardStatus == 'not_selected') {
      return 'Not Selected - Better Luck Next Time';
    }

    // For regular status
    switch (status?.toLowerCase()) {
      case 'claimed':
        return 'Claimed';
      case 'issued':
        return 'Ready to Claim';
      case 'pending':
        return 'Pending';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return const Center(child: Text('Please login to view rewards'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('rewards_earned')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.card_giftcard, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No rewards earned yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete activities to earn rewards',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        final rewards = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rewards.length,
          itemBuilder: (context, index) {
            final rewardDoc = rewards[index];
            final rewardData = rewardDoc.data() as Map<String, dynamic>;
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('activity_participants')
                  .doc('${rewardData['activity_id']}_${user.uid}')
                  .get(),
              builder: (context, participantSnapshot) {
                String? rewardStatus;
                if (participantSnapshot.hasData && participantSnapshot.data!.exists) {
                  final participantData = participantSnapshot.data!.data() as Map<String, dynamic>?;
                  rewardStatus = participantData?['rewardStatus'] as String?;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: Icon(
                      Icons.card_giftcard,
                      color: _getStatusColor(rewardData['status'] as String?),
                      size: 32,
                    ),
                    title: Text(
                      rewardData['reward_title'] ?? 'Reward',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(rewardData['status'] as String?)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(
                              rewardData['status'] as String?,
                              rewardStatus,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(rewardData['status'] as String?),
                            ),
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
                            _buildInfoRow(
                              'Reward Type',
                              (rewardData['reward_type'] ?? 'Unknown').toString().toUpperCase(),
                            ),
                            if (rewardData['reward_value'] != null)
                              _buildInfoRow(
                                'Value',
                                '${rewardData['reward_value']} ${rewardData['reward_type'] == 'coins' ? 'Coins' : ''}',
                              ),
                            if (rewardData['reward_code'] != null)
                              _buildInfoRow(
                                'Code',
                                rewardData['reward_code'].toString(),
                              ),
                            _buildInfoRow(
                              'Earned On',
                              _formatDate(rewardData['timestamp'] as Timestamp?),
                            ),
                            if (rewardData['claimed_at'] != null)
                              _buildInfoRow(
                                'Claimed On',
                                _formatDate(rewardData['claimed_at'] as Timestamp?),
                              ),
                            if (rewardData['reward_description'] != null &&
                                (rewardData['reward_description'] as String).isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Description:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    rewardData['reward_description'].toString(),
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
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
            width: 100,
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
