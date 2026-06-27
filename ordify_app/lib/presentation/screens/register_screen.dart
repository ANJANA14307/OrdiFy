import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/auth/auth_notifier.dart';
import '../workspace/ordify_workspace_widgets.dart';
import 'auth_ui_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _businessController = TextEditingController();
  final _instagramController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _businessController.dispose();
    _instagramController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _register() {
    final businessName = _businessController.text.trim();
    final instagramHandle = _instagramController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (businessName.isEmpty) {
      showOrdifyAuthSnack(context, 'Business name is required');
      return;
    }

    if (!email.contains('@')) {
      showOrdifyAuthSnack(context, 'Enter a valid email address');
      return;
    }

    if (password.length < 6) {
      showOrdifyAuthSnack(context, 'Password must be at least 6 characters');
      return;
    }

    ref.read(authProvider.notifier).signUpWithBusiness(
          email: email,
          password: password,
          businessName: businessName,
          instagramHandle: instagramHandle,
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
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => context.go('/login'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: ordifyCard.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: ordifyGreen,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const OrdifyAuthBrand(),
                ],
              ),

              const SizedBox(height: 42),

              Text(
                'Start your shop\nwith OrdiFy.',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 41,
                  height: 1.04,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Create your seller workspace to manage products, orders, customers, and business tasks easily.',
                style: GoogleFonts.inter(
                  color: Colors.white60,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 30),

              OrdifyAuthCard(
                child: Column(
                  children: [
                    OrdifyAuthInput(
                      controller: _businessController,
                      label: 'BUSINESS NAME',
                      hint: 'Example: Anjana Boutique',
                      icon: Icons.storefront_rounded,
                    ),
                    const SizedBox(height: 14),
                    OrdifyAuthInput(
                      controller: _instagramController,
                      label: 'INSTAGRAM HANDLE',
                      hint: '@your_shop',
                      icon: Icons.alternate_email_rounded,
                    ),
                    const SizedBox(height: 14),
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
                      label: 'CREATE PASSWORD',
                      hint: 'Minimum 6 characters',
                      icon: Icons.lock_rounded,
                      obscureText: true,
                    ),
                    const SizedBox(height: 22),
                    OrdifyAuthButton(
                      label: 'Create shop account',
                      isLoading: isLoading,
                      onPressed: _register,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      children: const [
                        TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Log in',
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
            ],
          ),
        ),
      ),
    );
  }
}