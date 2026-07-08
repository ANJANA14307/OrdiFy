import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/auth/auth_notifier.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _bizNameController = TextEditingController();
  final _instaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _bizNameController.dispose();
    _instaController.dispose();
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
            success ? const Color(0xFF0E7A4F) : Colors.orange.shade800,
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

        if (current.message.toLowerCase().contains('account created')) {
          context.go('/login');
        }
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.go('/login'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D11),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1A1A22),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: Color(0xFF35E58F),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Initialize\nWorkspace.',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 44,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Launch your brand dashboard and streamline your active catalog pipeline.',
                style: GoogleFonts.lexend(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
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
                              controller: _bizNameController,
                              decoration: const InputDecoration(
                                labelText: 'BUSINESS NAME',
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
                              controller: _instaController,
                              decoration: const InputDecoration(
                                labelText: 'INSTAGRAM HANDLE',
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
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
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
                              decoration: const InputDecoration(
                                labelText: 'CREATE PASSWORD',
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
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
                            ref
                                .read(authProvider.notifier)
                                .signUpWithBusiness(
                                  email: _emailController.text,
                                  password: _passwordController.text,
                                  businessName: _bizNameController.text,
                                  instagramHandle: _instaController.text,
                                );
                          },
                          child: Text(
                            'CREATE ACCOUNT',
                            style: GoogleFonts.lexend(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}