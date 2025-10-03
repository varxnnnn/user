// lib/core/services/auth_service.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';

// Result object for requesting an OTP
class PhoneOtpRequestResult {
  final String? verificationId;
  final PhoneAuthCredential? autoCredential;

  const PhoneOtpRequestResult({this.verificationId, this.autoCredential});
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // OTP-first: Request OTP before creating an account
  Future<PhoneOtpRequestResult> requestPhoneOtp(String phoneNumber) async {
    final completer = Completer<PhoneOtpRequestResult>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) {
        if (!completer.isCompleted) {
          completer.complete(PhoneOtpRequestResult(autoCredential: credential));
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Verification failed: ${e.message}'));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) {
          completer.complete(PhoneOtpRequestResult(verificationId: verificationId));
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) {
          completer.complete(PhoneOtpRequestResult(verificationId: verificationId));
        }
      },
    );

    return completer.future;
  }

  // Finalize signup only after OTP is verified
  Future<String> completeSignupAfterOtp({
    required String email,
    required String password,
    required String name,
    required String phone,
    int? age,
    String? gender,
    String? location,
    String? verificationId,
    String? smsCode,
    PhoneAuthCredential? autoCredential,
  }) async {
    try {
      // 1) Create the email/password account
      final emailCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = emailCredential.user;
      if (user == null) throw Exception('Failed to create user');

      // 2) Build phone credential
      final PhoneAuthCredential phoneCredential = autoCredential ?? PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: smsCode!,
      );

      // 3) Link phone to this user
      await user.linkWithCredential(phoneCredential);

      // 4) Create Firestore user doc ONLY AFTER phone is linked
      await UserService().createUser(
        uid: user.uid,
        email: email,
        name: name,
        phone: phone,
        age: age,
        gender: gender,
        location: location,
      );

      return user.uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Email already in use');
      } else if (e.code == 'weak-password') {
        throw Exception('Password is too weak');
      } else if (e.code == 'credential-already-in-use' || e.code == 'provider-already-linked') {
        throw Exception('Phone number already linked to another account');
      } else if (e.code == 'invalid-verification-code') {
        throw Exception('Invalid OTP');
      } else {
        throw Exception(e.message ?? 'Signup failed');
      }
    }
  }

  // Existing email/password signup
  Future<String?> signUpAndLinkPhone({
    required String email,
    required String password,
    required String name,
    required String phone,
    int? age,
    String? gender,
    String? location,
  }) async {
    try {
      // 1. Create email/password account
      UserCredential emailCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = emailCredential.user;
      if (user == null) return null;

      // 2. Create user doc in Firestore
      await UserService().createUser(
        uid: user.uid,
        email: email,
        name: name,
        phone: phone,
        age: age,
        gender: gender,
        location: location,
      );

      // 3. 🔥 LINK PHONE NUMBER TO THIS ACCOUNT
      await _linkPhoneNumberToCurrentUser(phone);

      return user.uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Email already in use');
      } else if (e.code == 'weak-password') {
        throw Exception('Password is too weak');
      } else {
        throw Exception(e.message ?? 'Signup failed');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // 🔥 STEP 2: Link phone to current user (requires OTP)
  Future<void> _linkPhoneNumberToCurrentUser(String phoneNumber) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');

    // Completer completes with credential on auto-verify, or completes with error when OTP is sent
    final completer = Completer<PhoneAuthCredential>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) {
        // Auto-verification (rare)
        if (!completer.isCompleted) {
          completer.complete(credential);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Verification failed: ${e.message}'));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        // Signal to caller that OTP entry is required
        if (!completer.isCompleted) {
          completer.completeError(Exception('OTP_REQUIRED:$verificationId'));
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // If auto retrieval times out, also require manual OTP entry
        if (!completer.isCompleted) {
          completer.completeError(Exception('OTP_REQUIRED:$verificationId'));
        }
      },
    );

    // If auto-verified
    final credential = await completer.future;
    await user.linkWithCredential(credential);
  }

  // 🔥 STEP 3: Complete phone linking with OTP
  Future<void> completePhoneLinking(String verificationId, String smsCode) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    await user.linkWithCredential(credential);
  }

  // Existing sign-in
  Future<void> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = userCredential.user;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!doc.exists) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            "email": user.email,
            "uid": user.uid,
            "created_at": FieldValue.serverTimestamp(),
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        throw Exception('Invalid email or password');
      }
      throw Exception(e.message ?? 'Login failed');
    }
  }

  Future<void> signOut() async => _auth.signOut();
}