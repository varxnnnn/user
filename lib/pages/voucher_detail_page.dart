// lib/pages/voucher_detail_page.dart
import 'package:flutter/material.dart';

class VoucherDetailPage extends StatelessWidget {
  final Map<String, dynamic> voucher;

  const VoucherDetailPage({super.key, required this.voucher});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Voucher Details"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and value
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: voucher["color"] as Color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.local_offer,
                    color: Colors.white,
                    size: 60,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${voucher["value"]} ${voucher["currency"]}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              voucher["title"] ?? "Untitled Voucher",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Description
            if ((voucher["description"] as String?)?.isNotEmpty == true)
              Text(
                voucher["description"],
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),

            const SizedBox(height: 16),

            // Info Tiles
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    icon: Icons.inventory,
                    label: "Available",
                    value: voucher["available_quantity"].toString(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoTile(
                    icon: Icons.check_circle_outline,
                    label: "Status",
                    value: voucher["status"] ?? "Active",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildInfoTile(
              icon: Icons.person,
              label: "Sponsor",
              value: voucher["sponsor_id"] ?? "Unknown",
            ),

            const SizedBox(height: 32),

            // Claim Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Add actual claim logic
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Voucher claimed successfully!")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Claim Voucher",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.orange, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}