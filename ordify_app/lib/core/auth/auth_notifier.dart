import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Auth States ---
abstract class AuthState {}
class AuthInitial extends AuthState {} // Used EXCLUSIVELY for the Splash Screen display window
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
    // Let the splash screen animate for a full 2 seconds
    await Future.delayed(const Duration(seconds: 6));

    final initialSession = _supabase.auth.currentSession;
    if (initialSession != null) {
      state = AuthSuccess();
    } else {
      // Not logged in? Shift to AuthError with an empty string to signal the router to open /login
      state = AuthError(''); 
    }

    // Listen for real-time authentication events across the app
    _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        state = AuthSuccess();
      } else {
        state = AuthError('');
      }
    });
  }

  // Business Registration Pipeline
  Future<void> signUpWithBusiness({
    required String email,
    required String password,
    required String businessName,
    required String instagramHandle,
  }) async {
    state = AuthLoading();
    try {
      final response = await _supabase.auth.signUp(
  email: email,
  password: password,
  data: {
    'business_name': businessName,
    'instagram_handle': instagramHandle,
  },
);

if (response.session != null) {
  state = AuthSuccess();
} else {
  state = AuthError('Account created. Please confirm your email, then log in.');
}
    } on AuthException catch (e) {
      state = AuthError(e.message);
    } catch (e) {
      state = AuthError('Something went wrong. Please try again.');
    }
  }

  // Log-In Pipeline
  Future<void> signIn({required String email, required String password}) async {
    state = AuthLoading();
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      state = AuthSuccess();
    } on AuthException catch (e) {
      state = AuthError(e.message);
    } catch (e) {
      state = AuthError('Authentication failed. Please check your credentials.');
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    state = AuthError(''); // Triggers router to move back to login immediately
  }
}

// --- Provider ---
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);