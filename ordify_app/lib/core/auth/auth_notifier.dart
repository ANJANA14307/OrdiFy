import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Auth States ---
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// --- Auth Notifier ---
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthInitial()) {
    _initAuthListener();
  }

  final _supabase = Supabase.instance.client;

  void _initAuthListener() async {
    await Future.delayed(const Duration(seconds: 2));

    final initialSession = _supabase.auth.currentSession;

    if (initialSession != null) {
      state = AuthSuccess();
    } else {
      state = AuthError('');
    }

    _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;

      if (session != null) {
        state = AuthSuccess();
      } else {
        state = AuthError('');
      }
    });
  }

  Future<void> signUpWithBusiness({
    required String email,
    required String password,
    required String businessName,
    required String instagramHandle,
  }) async {
    state = AuthLoading();

    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password.trim(),
        data: {
          'business_name': businessName.trim(),
          'instagram_handle': instagramHandle.trim(),
        },
      );

      if (response.session != null) {
        state = AuthSuccess();
      } else {
        state = AuthError(
          'Account created. Please login now.',
        );
      }
    } on AuthException catch (e) {
      state = AuthError(e.message);
    } catch (e) {
      state = AuthError('Something went wrong. Please try again.');
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = AuthLoading();

    try {
      await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      state = AuthSuccess();
    } on AuthException catch (e) {
      state = AuthError(e.message);
    } catch (e) {
      state = AuthError('Authentication failed. Please check your credentials.');
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    state = AuthError('');
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);