import 'package:flutter/foundation.dart';
import 'package:giftardo/core/services/profile_service.dart';

class ProfileProvider with ChangeNotifier {
  final ProfileService _service = ProfileService();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String _selectedLanguage = "English";
  bool _isNotified = true;

  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  String get selectedLanguage => _selectedLanguage;
  bool get isNotified => _isNotified;

  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();
    try {
      _userData = await _service.fetchUserProfile();
      
      // Load preferences from DB or use defaults
      _selectedLanguage = _userData?['language'] ?? "English";
      _isNotified = _userData?['notifications_enabled'] ?? true;
    } catch (e) {
      _userData = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateLanguage(String lang) async {
    await _service.updateLanguage(lang);
    _selectedLanguage = lang;
    notifyListeners();
    
    // Update local userData too
    if (_userData != null) {
      _userData!['language'] = lang;
    }
  }

  Future<void> toggleNotifications(bool value) async {
    await _service.updateNotificationPreference(value);
    _isNotified = value;
    notifyListeners();
    
    if (_userData != null) {
      _userData!['notifications_enabled'] = value;
    }
  }
}