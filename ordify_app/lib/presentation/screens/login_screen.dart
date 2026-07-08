import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/auth/auth_notifier.dart';

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

  void _showMessage(String message, {bool success = false}) {
    if (message.trim().isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor:
            success ? const Color(0xFF0E7A4F) : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, current) {
      if (current is AuthError) {
        _showMessage(current.message);
      }

      if (current is AuthSuccess) {
        context.go('/dashboard');
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF050A08),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Color(0xFF35E58F),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ORDIFY',
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                              color: const Color(0xFF35E58F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Control\nYour Engine.',
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(
                                fontSize: 44,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sign in to manage inventory, orders, customers and business analytics.',
                          style: GoogleFonts.lexend(
                            color: Colors.grey[500],
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF07070A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF14141A),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.lexend(fontSize: 15),
                                decoration: const InputDecoration(
                                  labelText: 'EMAIL ADDRESS',
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              Container(
                                height: 1,
                                color: const Color(0xFF14141A),
                              ),
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                style: GoogleFonts.lexend(fontSize: 15),
                                decoration: const InputDecoration(
                                  labelText: 'PASSWORD',
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (authState is AuthLoading)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF35E58F),
                            ),
                          )
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF35E58F),
                              foregroundColor: Colors.black,
                              minimumSize: const Size.fromHeight(60),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              ref.read(authProvider.notifier).signIn(
                                    email: _emailController.text,
                                    password: _passwordController.text,
                                  );
                            },
                            child: Text(
                              'AUTHENTICATE',
                              style: GoogleFonts.lexend(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextButton(
                          onPressed: () => context.go('/register'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF35E58F),
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.lexend(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                              children: const [
                                TextSpan(text: 'New here? '),
                                TextSpan(
                                  text: 'Register your business',
                                  style: TextStyle(
                                    color: Color(0xFF35E58F),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
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