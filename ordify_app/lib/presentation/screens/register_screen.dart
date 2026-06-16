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

  String _passwordStrength = 'Weak';
  double _strength = 0;

  @override
  void dispose() {
    _bizNameController.dispose();
    _instaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (_bizNameController.text.trim().isEmpty) {
      _showError('Business name is required');
      return false;
    }

    if (_instaController.text.trim().isEmpty) {
      _showError('Instagram handle is required');
      return false;
    }

    if (!_emailController.text.contains('@')) {
      _showError('Enter a valid email address');
      return false;
    }

    if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return false;
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _checkPassword(String password) {
    double score = 0;

    if (password.length >= 8) score += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 0.25;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 0.25;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) {
      score += 0.25;
    }

    setState(() {
      _strength = score;

      if (score <= 0.25) {
        _passwordStrength = 'Weak';
      } else if (score <= 0.5) {
        _passwordStrength = 'Medium';
      } else if (score <= 0.75) {
        _passwordStrength = 'Good';
      } else {
        _passwordStrength = 'Strong';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, current) {
      if (current is AuthSuccess) {
        context.go('/dashboard');
      }

      if (current is AuthError && current.message.isNotEmpty) {
        _showError(current.message);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
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
                    border: Border.all(color: const Color(0xFF1A1A22)),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: Color(0xFF00FFCC),
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
                      PremiumInputField(
                        label: 'BUSINESS NAME',
                        hint: 'Example: Anjana Boutique',
                        controller: _bizNameController,
                      ),

                      const SizedBox(height: 18),

                      PremiumInputField(
                        label: 'INSTAGRAM HANDLE',
                        hint: '@anjana_store',
                        controller: _instaController,
                      ),

                      const SizedBox(height: 18),

                      PremiumInputField(
                        label: 'EMAIL ADDRESS',
                        hint: 'you@example.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 18),

                      PremiumInputField(
                        label: 'CREATE PASSWORD',
                        hint: 'Minimum 6 characters',
                        controller: _passwordController,
                        obscureText: true,
                        onChanged: _checkPassword,
                      ),

                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _strength,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(20),
                          backgroundColor: const Color(0xFF14141A),
                          color: _strength < 0.3
                              ? Colors.red
                              : _strength < 0.7
                                  ? Colors.orange
                                  : const Color(0xFF00FFCC),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Password Strength: $_passwordStrength',
                            style: GoogleFonts.lexend(
                              color: _strength < 0.3
                                  ? Colors.red
                                  : _strength < 0.7
                                      ? Colors.orange
                                      : const Color(0xFF00FFCC),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),

                      if (authState is AuthLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00FFCC),
                          ),
                        )
                      else
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FFCC),
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (!_validateForm()) return;

                            ref
                                .read(authProvider.notifier)
                                .signUpWithBusiness(
                                  email: _emailController.text.trim(),
                                  password: _passwordController.text.trim(),
                                  businessName:
                                      _bizNameController.text.trim(),
                                  instagramHandle:
                                      _instaController.text.trim(),
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

class PremiumInputField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const PremiumInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
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
          onChanged: onChanged,
          style: GoogleFonts.lexend(
            color: Colors.white,
            fontSize: 15,
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