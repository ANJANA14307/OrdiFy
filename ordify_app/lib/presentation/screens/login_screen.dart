import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/auth/auth_notifier.dart';
import '../workspace/ordify_workspace_widgets.dart';
import 'auth_ui_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!email.contains('@')) {
      showOrdifyAuthSnack(context, 'Enter a valid email address');
      return;
    }

    if (password.isEmpty) {
      showOrdifyAuthSnack(context, 'Password is required');
      return;
    }

    ref.read(authProvider.notifier).signIn(
          email: email,
          password: password,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading;

    ref.listen<AuthState>(authProvider, (previous, current) {
      if (current is AuthSuccess) {
        context.go('/dashboard');
      }

      if (current is AuthError && current.message.isNotEmpty) {
        showOrdifyAuthSnack(context, current.message);
      }
    });

    return Scaffold(
      backgroundColor: ordifyBg,
      body: OrdifyAuthBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            children: [
              const OrdifyAuthBrand(),

              const SizedBox(height: 58),

              Text(
                'Your business,\nsimplified.',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 43,
                  height: 1.04,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.3,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Log in to manage your orders, products, customers, and daily seller tasks from one clean workspace.',
                style: GoogleFonts.inter(
                  color: Colors.white60,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 34),

              OrdifyAuthCard(
                child: Column(
                  children: [
                    OrdifyAuthInput(
                      controller: _emailController,
                      label: 'EMAIL ADDRESS',
                      hint: 'you@example.com',
                      icon: Icons.mail_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    OrdifyAuthInput(
                      controller: _passwordController,
                      label: 'PASSWORD',
                      hint: 'Enter your password',
                      icon: Icons.lock_rounded,
                      obscureText: true,
                    ),
                    const SizedBox(height: 22),
                    OrdifyAuthButton(
                      label: 'Log in to OrdiFy',
                      isLoading: isLoading,
                      onPressed: _login,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              Center(
                child: TextButton(
                  onPressed: () => context.go('/register'),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      children: const [
                        TextSpan(text: 'New to OrdiFy? '),
                        TextSpan(
                          text: 'Create your shop account',
                          style: TextStyle(
                            color: ordifyGreen,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              OrdifyAuthCard(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: ordifyGreen.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        color: ordifyGreen,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        'Built for Instagram sellers and small businesses who want simple order and stock control.',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}