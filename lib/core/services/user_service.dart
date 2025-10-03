import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUser({
    required String uid,
    required String email,
    required String name,
    required String phone,
    int? age,
    String? gender,
    String? location,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      "name": name,
      "email": email,
      "phone": phone,
      "age": age,
      "gender": gender,
      "location": location,
      "points": 0,
      "created_at": FieldValue.serverTimestamp(),
      "updated_at": FieldValue.serverTimestamp(),
    });
  }
}