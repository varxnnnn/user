import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageRewardsTab extends StatefulWidget {
  const ManageRewardsTab({super.key});

  @override
  _ManageRewardsTabState createState() => _ManageRewardsTabState();
}

class _ManageRewardsTabState extends State<ManageRewardsTab> {
  String? sponsorId;
  String searchQuery = '';

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

  Future<void> updateRewardStatus(String rewardId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('sponsor_rewards')
          .doc(rewardId)
          .update({
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reward status updated to $newStatus")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating status: $e")),
      );
    }
  }

  Future<void> deleteReward(String rewardId) async {
    try {
      await FirebaseFirestore.instance
          .collection('sponsor_rewards')
          .doc(rewardId)
          .delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reward deleted successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting reward: $e")),
      );
    }
  }

  Widget _buildMetadataWidget(Map<String, dynamic> metadata, String type) {
    switch (type) {
      case "voucher":
        final voucher = metadata['voucher'] as Map<String, dynamic>?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Value: ${voucher?['value'] ?? 0} ${voucher?['currency'] ?? 'INR'}"),
          ],
        );
      case "coins":
        final coins = metadata['coins'] as Map<String, dynamic>?;
        return Text("Amount: ${coins?['amount'] ?? 0} coins");
      case "product":
        final product = metadata['product'] as Map<String, dynamic>?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Name: ${product?['name'] ?? 'N/A'}"),
            Text("Brand: ${product?['brand'] ?? 'N/A'}"),
            if (product?['category'] != null)
              Text("Category: ${product?['category']}"),
            if (product?['price'] != null)
              Text("Price: ₹${product?['price']}"),
            if (product?['type'] != null)
              Text("Type: ${product?['type']}"),
          ],
        );
      default:
        return const Text("No metadata available");
    }
  }

  Widget _buildRewardCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rewardId = doc.id;
    final type = data['type'] as String? ?? 'unknown';
    final totalQuantity = data['total_quantity'] as int? ?? 0;
    final availableQuantity = data['available_quantity'] as int? ?? 0;
    final status = data['status'] as String? ?? 'unknown';
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
    final createdAt = data['created_at'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                    "Reward ID: ${rewardId.substring(0, 8)}...",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'active' ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text("Type: ${type.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text("Total: $totalQuantity | Available: $availableQuantity"),
            const SizedBox(height: 8),
            _buildMetadataWidget(metadata, type),
            if (createdAt != null) ...[
              const SizedBox(height: 8),
              Text("Created: ${createdAt.toDate().toString().split(' ')[0]}"),
            ],
            const SizedBox(height: 12),
            
            // Individual Items Section
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sponsor_rewards')
                  .doc(rewardId)
                  .collection('items')
                  .limit(5) // Show only first 5 items
                  .snapshots(),
              builder: (context, itemsSnapshot) {
                if (itemsSnapshot.hasData && itemsSnapshot.data!.docs.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Recent Items:", style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      ...itemsSnapshot.data!.docs.map((itemDoc) {
                        final itemData = itemDoc.data() as Map<String, dynamic>;
                        final code = itemData['code'] as String?;
                        final itemStatus = itemData['status'] as String? ?? 'unknown';
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(itemStatus).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getStatusColor(itemStatus), width: 1),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  code ?? "No Code",
                                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(itemStatus),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  itemStatus.toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      if (totalQuantity > 5) ...[
                        const SizedBox(height: 4),
                        Text("... and ${totalQuantity - 5} more items", 
                             style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _showAllItemsDialog(rewardId, type),
                        child: const Text("View All Items"),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showStatusDialog(rewardId, status),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Update Status"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showDeleteDialog(rewardId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Delete"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'assigned':
        return Colors.orange;
      case 'redeemed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showAllItemsDialog(String rewardId, String type) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("All Items - $type", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sponsor_rewards')
                      .doc(rewardId)
                      .collection('items')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("No items found"));
                    }

                    // Sort items by created_at descending
                    final sortedDocs = List<DocumentSnapshot>.from(snapshot.data!.docs);
                    sortedDocs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aCreated = aData['created_at'] as Timestamp?;
                      final bCreated = bData['created_at'] as Timestamp?;
                      
                      if (aCreated == null && bCreated == null) return 0;
                      if (aCreated == null) return 1;
                      if (bCreated == null) return -1;
                      
                      return bCreated.compareTo(aCreated); // Descending order
                    });

        return ListView.builder(
                      itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
                        final itemDoc = sortedDocs[index];
                        final itemData = itemDoc.data() as Map<String, dynamic>;
                        final code = itemData['code'] as String?;
                        final value = itemData['value'] as int? ?? 0;
                        final status = itemData['status'] as String? ?? 'unknown';
                        final assignedTo = itemData['assigned_to'] as String?;
                        final activityId = itemData['activity_id'] as String?;
                        final createdAt = itemData['created_at'] as Timestamp?;

            return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                            title: Text(code ?? "No Code", style: const TextStyle(fontFamily: 'monospace')),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                                Text("Value: $value"),
                                if (assignedTo != null) Text("Assigned to: ${assignedTo.substring(0, 8)}..."),
                                if (activityId != null) Text("Activity: ${activityId.substring(0, 8)}..."),
                                if (createdAt != null) Text("Created: ${createdAt.toDate().toString().split(' ')[0]}"),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                                color: _getStatusColor(status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _showStatusDialog(String rewardId, String currentStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Status"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Active"),
              leading: Radio<String>(
                value: "active",
                groupValue: currentStatus,
                onChanged: (value) {
                  Navigator.pop(context);
                  updateRewardStatus(rewardId, value!);
                },
              ),
            ),
            ListTile(
              title: const Text("Inactive"),
              leading: Radio<String>(
                value: "inactive",
                groupValue: currentStatus,
                onChanged: (value) {
                  Navigator.pop(context);
                  updateRewardStatus(rewardId, value!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(String rewardId) {
    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Delete Reward"),
        content: const Text("Are you sure you want to delete this reward? This action cannot be undone."),
                        actions: [
                          TextButton(
            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              deleteReward(rewardId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
  }

  @override
  Widget build(BuildContext context) {
    if (sponsorId == null) {
      return const Center(child: Text("Loading sponsor ID..."));
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              labelText: "Search rewards by type...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value.toLowerCase();
              });
            },
          ),
        ),

        // Rewards List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                          .collection('sponsor_rewards')
                .where('sponsor_id', isEqualTo: sponsorId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No rewards found"));
              }

              // Filter and sort rewards based on search query
              final filteredDocs = snapshot.data!.docs.where((doc) {
                if (searchQuery.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final type = (data['type'] as String? ?? '').toLowerCase();
                return type.contains(searchQuery);
              }).toList();

              // Sort by created_at descending (newest first)
              filteredDocs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aCreated = aData['created_at'] as Timestamp?;
                final bCreated = bData['created_at'] as Timestamp?;
                
                if (aCreated == null && bCreated == null) return 0;
                if (aCreated == null) return 1;
                if (bCreated == null) return -1;
                
                return bCreated.compareTo(aCreated); // Descending order
              });

              if (filteredDocs.isEmpty) {
                return const Center(child: Text("No rewards match your search"));
              }

              return ListView.builder(
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  return _buildRewardCard(filteredDocs[index]);
                },
                  );
                },
              ),
        ),
      ],
    );
  }
}