// lib/providers/auth_provider.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:giftardo/core/services/auth_service.dart';
import 'package:firebase_storage/firebase_storage.dart'; // 👈 NEW

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; // 👈 NEW

  bool _isLoading = false;
  String? _error;
  String? _pendingVerificationId;
  User? _user;
  bool _isInitialized = false;

  // Stash signup data
  String? _pendingEmail;
  String? _pendingPassword;
  String? _pendingName;
  String? _pendingPhone;
  int? _pendingAge;
  String? _pendingGender;
  String? _pendingLocation;
  String? _pendingReferralCode;
  File? _pendingProfileImage; // 👈 NEW

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get pendingVerificationId => _pendingVerificationId;
  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    _init();
  }

  void _init() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isInitialized = true;
      notifyListeners();
    });
  }

  Future<bool> requestOtpAndPrepareSignup({
    required String email,
    required String password,
    required String name,
    required String phone,
    int? age,
    String? gender,
    String? location,
    String? referralCode,
    File? profileImage, // 👈 NEW
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.requestPhoneOtp(phone);

      _pendingEmail = email;
      _pendingPassword = password;
      _pendingName = name;
      _pendingPhone = phone;
      _pendingAge = age;
      _pendingGender = gender;
      _pendingLocation = location;
      _pendingReferralCode = referralCode;
      _pendingProfileImage = profileImage; // 👈 STASH IMAGE

      if (result.autoCredential != null) {
        await _authService.completeSignupAfterOtp(
          email: email,
          password: password,
          name: name,
          phone: phone,
          age: age,
          gender: gender,
          location: location,
          autoCredential: result.autoCredential,
          referralCode: referralCode,
        );
        // 👇 Upload profile image after user is created
        await _uploadProfileImage(profileImage);
        _clearPending();
        return true;
      }

      _pendingVerificationId = result.verificationId;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitOtpAndSignUp(String smsCode) async {
    if (_pendingVerificationId == null ||
        _pendingEmail == null ||
        _pendingPassword == null ||
        _pendingName == null ||
        _pendingPhone == null) {
      _error = 'No pending signup';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.completeSignupAfterOtp(
        email: _pendingEmail!,
        password: _pendingPassword!,
        name: _pendingName!,
        phone: _pendingPhone!,
        age: _pendingAge,
        gender: _pendingGender,
        location: _pendingLocation,
        verificationId: _pendingVerificationId,
        smsCode: smsCode,
        referralCode: _pendingReferralCode,
      );

      // 👇 Upload profile image after successful signup
      await _uploadProfileImage(_pendingProfileImage);

      _clearPending();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 👇 NEW: Upload profile image to Firebase Storage
  Future<void> _uploadProfileImage(File? imageFile) async {
    if (imageFile == null || _user?.uid == null) return;

    try {
      final ref = _storage.ref().child('profiles/${_user!.uid}.jpg');
      await ref.putFile(imageFile);
      // Optional: You can save download URL to Firestore if needed
    } catch (e) {
      debugPrint('Profile image upload failed: $e');
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signIn(email, password);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }

  void _clearPending() {
    _pendingVerificationId = null;
    _pendingEmail = null;
    _pendingPassword = null;
    _pendingName = null;
    _pendingPhone = null;
    _pendingAge = null;
    _pendingGender = null;
    _pendingLocation = null;
    _pendingReferralCode = null;
    _pendingProfileImage = null; // 👈 CLEAR
  }
}