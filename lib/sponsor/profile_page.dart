import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? userRole;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sponsorId = prefs.getString('sponsorId');
      final adminId = prefs.getString('adminId');
      
      if (sponsorId != null) {
        userRole = 'sponsor';
        final doc = await FirebaseFirestore.instance
            .collection('sponsors')
            .doc(sponsorId)
            .get();
        setState(() {
          userData = doc.data();
          isLoading = false;
        });
      } else if (adminId != null) {
        userRole = 'admin';
        final doc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(adminId)
            .get();
        setState(() {
          userData = doc.data();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (userData == null) {
      return const Center(child: Text('No profile data found'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  if (userRole == 'sponsor' && userData!['profile_pic'] != null)
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(userData!['profile_pic']),
                    )
                  else
                    const CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 50),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    userData!['name'] ?? 'No Name',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    userRole?.toUpperCase() ?? '',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildInfoCard('Email', userData!['email']),
            _buildInfoCard('Phone', userData!['phone']),
            if (userRole == 'sponsor') ...[
              _buildInfoCard('Contact Person', userData!['contact_person']),
              _buildInfoCard('Address', userData!['address']),
              _buildInfoCard('Status', userData!['status']),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
                child: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: ListTile(
          title: Text(label),
          subtitle: Text(value ?? 'Not provided'),
        ),
      ),
    );
  }
}
