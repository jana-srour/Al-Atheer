import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? _user;
  bool _isAdmin = false;
  bool _isLoading = true;
  bool _isPasswordRecovery = false;
  String? _displayName;
  String? _profileError;
  StreamSubscription<AuthState>? _authSubscription;
  int _authRevision = 0;

  User? get user => _user;
  bool get isAdmin => _isAdmin;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isPasswordRecovery => _isPasswordRecovery;
  String get displayName {
    final name = _displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final metadataName = _user?.userMetadata?['display_name']
        ?.toString()
        .trim();
    if (metadataName != null && metadataName.isNotEmpty) return metadataName;
    return _user?.email?.split('@').first ?? 'Guest';
  }

  String? get profileError => _profileError;

  Future<List<Map<String, dynamic>>> fetchAdminAccessList() async {
    if (!isAdmin) throw StateError('Administrator access is required.');
    final response = await _supabase.rpc('list_admin_access');
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<String?> setAdminAccess(String email, {required bool enabled}) async {
    if (!isAdmin) return 'Administrator access is required.';
    try {
      await _supabase.rpc(
        'manage_admin_access',
        params: {'target_email': email.trim(), 'enable_admin': enabled},
      );
      return null;
    } on PostgrestException catch (error) {
      return error.message;
    } catch (error) {
      return 'Could not update administrator access: $error';
    }
  }

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      final revision = ++_authRevision;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
      } else if (data.event == AuthChangeEvent.signedOut) {
        _isPasswordRecovery = false;
      }
      _user = data.session?.user;
      if (_user != null) {
        await _fetchProfile(_user!, revision: revision);
      } else {
        _isAdmin = false;
        _displayName = null;
        _profileError = null;
      }
      if (revision != _authRevision) return;
      _isLoading = false;
      notifyListeners();
    });

    _user = _supabase.auth.currentUser;
    if (_user != null) {
      final revision = ++_authRevision;
      await _fetchProfile(_user!, revision: revision);
    }
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchProfile(User user, {required int revision}) async {
    _displayName = user.userMetadata?['display_name']?.toString();
    _profileError = null;
    try {
      final res = await _supabase
          .from('profiles')
          .select('is_admin, display_name')
          .eq('id', user.id)
          .maybeSingle();

      if (revision != _authRevision || _user?.id != user.id) return;
      if (res != null) {
        _isAdmin = res['is_admin'] == true;
        final name = res['display_name']?.toString().trim();
        _displayName = name == null || name.isEmpty ? null : name;
      } else {
        _isAdmin = false;
        _profileError =
            'Profile not found. Run the provided Supabase SQL setup.';
      }
    } catch (error) {
      if (revision != _authRevision || _user?.id != user.id) return;
      _isAdmin = false;
      _profileError =
          'Could not load the profile from Supabase. Run the provided SQL setup. ($error)';
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      _user = response.user;
      if (_user != null) {
        final revision = ++_authRevision;
        await _fetchProfile(_user!, revision: revision);
      }
      _isLoading = false;
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An unexpected error occurred.';
    }
  }

  Future<String?> signUp(
    String email,
    String password, {
    required String displayName,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName.trim()},
      );
      _user = response.session?.user;
      if (_user != null) {
        final revision = ++_authRevision;
        await _fetchProfile(_user!, revision: revision);
      } else {
        _isAdmin = false;
        _displayName = null;
      }
      _isLoading = false;
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An unexpected error occurred.';
    }
  }

  Future<String?> updateDisplayName(String displayName) async {
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty || normalizedName.length > 80) {
      return 'Name must be between 1 and 80 characters.';
    }
    if (_user == null) return 'Sign in to update your profile.';

    try {
      _isLoading = true;
      notifyListeners();
      await _supabase.rpc(
        'update_my_profile',
        params: {'new_display_name': normalizedName},
      );
      _displayName = normalizedName;
      _profileError = null;
      _isLoading = false;
      notifyListeners();
      return null;
    } on PostgrestException catch (error) {
      _isLoading = false;
      notifyListeners();
      return 'Could not save your profile (${error.code ?? 'database error'}): ${error.message}';
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      return 'Could not save your profile: $error';
    }
  }

  Future<String?> sendPasswordReset(String email, {String? redirectTo}) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _supabase.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
      _isLoading = false;
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An unexpected error occurred.';
    }
  }

  Future<String?> updatePassword(String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _supabase.auth.updateUser(UserAttributes(password: password));
      _isLoading = false;
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An unexpected error occurred.';
    }
  }

  void finishPasswordRecovery() {
    _isPasswordRecovery = false;
    notifyListeners();
  }

  Future<String?> signOut() async {
    if (_isLoading) return 'Please wait for the current account action to finish.';
    _isLoading = true;
    notifyListeners();
    try {
      await _supabase.auth.signOut();
      ++_authRevision;
      _user = null;
      _isAdmin = false;
      _displayName = null;
      _profileError = null;
      _isPasswordRecovery = false;
      _isLoading = false;
      notifyListeners();
      return null;
    } on AuthException catch (error) {
      _isLoading = false;
      notifyListeners();
      return error.message;
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      return 'Could not sign out: $error';
    }
  }
}
