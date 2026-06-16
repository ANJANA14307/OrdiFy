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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, current) {
      if (current is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(current.message, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Accent Brand Mark
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00FFCC),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ORDIFY',
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3.0,
                              color: const Color(0xFF00FFCC),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Main Header Scene
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Control\nYour Engine.',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 44,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sign in to sync your local workspace, track configurations, and manage business tasks effortlessly.',
                          style: GoogleFonts.lexend(
                            color: Colors.grey[500],
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Form Section Wrapped in a subtle premium container
PremiumInputField(
  label: 'EMAIL ADDRESS',
  hint: 'you@example.com',
  controller: _emailController,
  keyboardType: TextInputType.emailAddress,
),

const SizedBox(height: 18),

PremiumInputField(
  label: 'PASSWORD',
  hint: 'Enter your password',
  controller: _passwordController,
  obscureText: true,
),                        const SizedBox(height: 32),

                        // Primary Action Button
                        if (authState is AuthLoading)
                          const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)))
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00FFCC),
                              foregroundColor: Colors.black,
                              minimumSize: const Size.fromHeight(60),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              ref.read(authProvider.notifier).signIn(
                                email: _emailController.text.trim(),
                                password: _passwordController.text.trim(),
                              );
                            },
                            child: Text(
                              'AUTHENTICATE',
                              style: GoogleFonts.lexend(fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 14),
                            ),
                          ),
                      ],
                    ),

                    // Bottom Navigation Link
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: TextButton(
                          onPressed: () => context.go('/register'),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF00FFCC)),
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.lexend(color: Colors.grey[600], fontSize: 13),
                              children: const [
                                TextSpan(text: "New here? "),
                                TextSpan(
                                  text: "Register your business",
                                  style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold),
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
class PremiumInputField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType keyboardType;

  const PremiumInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.lexend(
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF00FFCC),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: GoogleFonts.lexend(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.lexend(
              color: Colors.white30,
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFF07070A),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF17171F),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF00FFCC),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}