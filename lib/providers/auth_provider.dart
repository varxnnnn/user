// lib/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:giftardo/core/services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  String? _error;
  String? _pendingVerificationId; // For OTP-first signup
  User? _user;
  bool _isInitialized = false;

  // Stash signup data until OTP is verified
  String? _pendingEmail;
  String? _pendingPassword;
  String? _pendingName;
  String? _pendingPhone;
  int? _pendingAge;
  String? _pendingGender;
  String? _pendingLocation;
  String? _pendingReferralCode; // 👈 ADD THIS

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

  // 🔥 OTP-first: request OTP and stash signup data
  Future<bool> requestOtpAndPrepareSignup({
  required String email,
  required String password,
  required String name,
  required String phone,
  int? age,
  String? gender,
  String? location,
  String? referralCode, // 👈 ADD PARAMETER
}) async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    final result = await _authService.requestPhoneOtp(phone);

    // Stash data for finalize step
    _pendingEmail = email;
    _pendingPassword = password;
    _pendingName = name;
    _pendingPhone = phone;
    _pendingAge = age;
    _pendingGender = gender;
    _pendingLocation = location;
    _pendingReferralCode = referralCode; // 👈 STASH IT

    if (result.autoCredential != null) {
      // Auto verified → finalize immediately
      await _authService.completeSignupAfterOtp(
        email: email,
        password: password,
        name: name,
        phone: phone,
        age: age,
        gender: gender,
        location: location,
        autoCredential: result.autoCredential,
        referralCode: referralCode, // 👈 PASS TO SERVICE
      );
      _clearPending();
      return true;
    }

    _pendingVerificationId = result.verificationId;
    notifyListeners();
    return false; // navigate to OTP screen
  } catch (e) {
    _error = e.toString();
    notifyListeners();
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

  // 🔥 Submit OTP and finalize signup
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
      referralCode: _pendingReferralCode, // 👈 PASS IT
    );
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

  // 🔥 Keep email/password login
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
  _pendingReferralCode = null; // 👈 CLEAR IT
}
}