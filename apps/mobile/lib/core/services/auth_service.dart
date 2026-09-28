import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sk_live/core/util/app_constants.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final SupabaseClient _client = Supabase.instance.client;

  bool _userInitiatedSignOut = false;

  bool get isUserInitiatedSignOut => _userInitiatedSignOut;

  void clearUserInitiatedSignOut() {
    _userInitiatedSignOut = false;
  }

  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signInWithOtp(String phone) async {
    try {
      await _client.auth.signInWithOtp(phone: phone);
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> verifyOtp(String phone, String token) async {
    try {
      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    try {
      const webClientId = AppConstants.googleWebClientId;

      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        scopes: const ['email', 'profile', 'openid'],
      );

      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw 'Login cancelled by user';
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw 'No ID Token from Google. Check Web client ID + Android SHA-1 '
            '(Play App Signing) on the same Cloud project as the Web client.';
      }

      return await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      throw _mapGoogleSignInError(e);
    }
  }

  static String _mapGoogleSignInError(Object e) {
    final raw = e.toString();
    final lower = raw.toLowerCase();

    if (raw.contains('10:') ||
        lower.contains('api_exception: 10') ||
        lower.contains('developer_error')) {
      return 'Google Sign-In misconfigured (error 10). '
          'Add Play App Signing SHA-1 + upload SHA-1 on the Android OAuth client '
          '(package com.sklive.app), same project as the Web client.';
    }
    if (raw.contains('12500') || lower.contains('sign_in_failed')) {
      return 'Google Sign-In failed (12500). Verify package name com.sklive.app '
          'and SHA fingerprints on the Android OAuth client.';
    }
    if (raw.contains('12501') || lower.contains('sign_in_cancelled')) {
      return 'Login cancelled by user';
    }
    if (lower.contains('id token') && lower.contains('audience')) {
      return 'Supabase rejected Google token. Web Client ID in app and '
          'Supabase Google provider must match exactly.';
    }
    if (lower.contains('provider is not enabled')) {
      return 'Google provider is disabled in Supabase Auth settings.';
    }
    return raw;
  }

  Future<AuthResponse> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status != LoginStatus.success) {
        throw 'Facebook login failed: ${result.message}';
      }

      final accessToken = result.accessToken?.tokenString;
      if (accessToken == null) throw 'No access token found.';

      return await _client.auth.signInWithIdToken(
        provider: OAuthProvider.facebook,
        idToken: accessToken,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signUp(email: email.trim(), password: password);
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  Future<void> resetPasswordForEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  static String mapAuthError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('invalid login credentials') ||
        message.contains('invalid email or password')) {
      return 'Invalid email or password.';
    }
    if (message.contains('user already registered') ||
        message.contains('already been registered')) {
      return 'This email is already registered. Try logging in.';
    }
    if (message.contains('password') && message.contains('weak')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (message.contains('valid email')) {
      return 'Please enter a valid email address.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please confirm your email before logging in.';
    }
    if (error is AuthException) {
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<Map<String, dynamic>?> fetchProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', user.id)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateProfile({
    String? username,
    String? gender,
    String? countryCode,
    String? bio,
    String? dateOfBirth,
  }) async {
    final user = currentUser;
    if (user == null) throw 'Not authenticated';

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
      if (username != null) 'username': username,
      if (gender != null) 'gender': gender,
      if (countryCode != null) 'country_code': countryCode,
      if (bio != null) 'bio': bio,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
    };

    if (updates.length <= 1) return;

    try {
      final rows = await _client
          .from('users')
          .update(updates)
          .eq('id', user.id)
          .select('id');

      if (rows.isEmpty) {
        throw 'Profile update blocked — check database permissions.';
      }
    } catch (e) {
      debugPrint('AuthService Error in updateProfile: $e');
      rethrow;
    }
  }

  Future<bool> isUsernameAvailable(
    String username, {
    String? excludeUserId,
  }) async {
    if (username.length < 3) return false;
    final userId = excludeUserId ?? currentUser?.id;
    try {
      var query = _client
          .from('users')
          .select('id')
          .ilike('username', username);
      if (userId != null) {
        query = query.neq('id', userId);
      }
      final response = await query.maybeSingle();

      return response == null;
    } catch (e) {
      debugPrint('AuthService isUsernameAvailable error: $e');
      return true;
    }
  }

  Future<void> signOut() async {
    _userInitiatedSignOut = true;
    try {
      await Future.wait([
        _client.auth.signOut(),
        GoogleSignIn(serverClientId: AppConstants.googleWebClientId).signOut(),
        FacebookAuth.instance.logOut(),
      ]);
    } catch (_) {
      clearUserInitiatedSignOut();
      rethrow;
    }
  }

  Future<void> signOutDueToOtherDevice() async {
    debugPrint('[Auth] signing out — session replaced on another device');
    _userInitiatedSignOut = true;
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('[Auth] local signOut after device takeover failed: $e');
      clearUserInitiatedSignOut();
    }
  }
}
