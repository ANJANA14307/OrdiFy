import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/api_client.dart';
import 'ordify_workspace_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  Map<String, dynamic> profile = {};

  final businessController = TextEditingController();
  final instagramController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  @override
  void dispose() {
    businessController.dispose();
    instagramController.dispose();
    super.dispose();
  }

  Future<void> fetchProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await apiClient.get('/profile/me');
      final data = Map<String, dynamic>.from(response.data as Map);

      profile = data;
      businessController.text = data['business_name']?.toString() ?? '';
      instagramController.text = data['instagram_handle']?.toString() ?? '';

      setState(() {
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  Future<void> saveProfile() async {
    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      final response = await apiClient.patch(
        '/profile/me',
        data: {
          'business_name': businessController.text.trim(),
          'instagram_handle': instagramController.text.trim(),
        },
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      final updatedProfile = Map<String, dynamic>.from(data['profile'] ?? {});

      setState(() {
        profile = {
          ...profile,
          ...updatedProfile,
        };
        isSaving = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F2419),
          content: Text(
            'Profile updated successfully',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
        isSaving = false;
      });
    }
  }

  Future<void> signOut() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101010),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Sign out?',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'You can login again with the correct account after signing out.',
            style: GoogleFonts.inter(
              color: Colors.white60,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Sign Out',
                style: GoogleFonts.inter(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;
      context.go('/login');
    }
  }

  String cleanInstagram(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Not set';
    }

    final clean = value.trim();

    if (clean.startsWith('@')) {
      return clean;
    }

    return '@$clean';
  }

  @override
  Widget build(BuildContext context) {
    final email = profile['email']?.toString() ?? 'No email';
    final plan = profile['plan_tier']?.toString() ?? 'free';
    final businessName = profile['business_name']?.toString() ?? 'My Business';
    final instagram = cleanInstagram(profile['instagram_handle']?.toString());

    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.25,
            colors: [
              Color(0xFF16C76A),
              Color(0xFF0A2418),
              Color(0xFF050807),
            ],
            stops: [0.0, 0.36, 1.0],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF34F087),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF34F087),
                  backgroundColor: const Color(0xFF0B1510),
                  onRefresh: fetchProfile,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                    children: [
                      _Header(
                        onBack: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/dashboard');
                          }
                        },
                        onRefresh: fetchProfile,
                      ),

                      const SizedBox(height: 18),

                      OrdifyGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _GlowText(
                              'Business Profile',
                              fontSize: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Manage your store identity and account details.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFE8FFF2),
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Container(
                                  height: 62,
                                  width: 62,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF34F087),
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF34F087)
                                            .withOpacity(0.35),
                                        blurRadius: 22,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.storefront_rounded,
                                    color: Color(0xFF052113),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _GlowText(
                                        businessName,
                                        fontSize: 19,
                                        soft: true,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        instagram,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFE8FFF2),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      OrdifyGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _GlowText(
                              'Edit Details',
                              fontSize: 22,
                            ),
                            const SizedBox(height: 16),
                            _InputField(
                              controller: businessController,
                              label: 'Business Name',
                              icon: Icons.store_rounded,
                            ),
                            const SizedBox(height: 14),
                            _InputField(
                              controller: instagramController,
                              label: 'Instagram Handle',
                              icon: Icons.alternate_email_rounded,
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: isSaving ? null : saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF34F087),
                                  foregroundColor: const Color(0xFF052113),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                icon: isSaving
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF052113),
                                        ),
                                      )
                                    : const Icon(Icons.save_rounded),
                                label: Text(
                                  isSaving ? 'Saving...' : 'Save Profile',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _ErrorCard(message: errorMessage!),
                      ],

                      const SizedBox(height: 18),

                      OrdifyGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _GlowText(
                              'Account Info',
                              fontSize: 22,
                            ),
                            const SizedBox(height: 14),
                            _InfoRow(
                              icon: Icons.email_rounded,
                              title: 'Email',
                              value: email,
                              color: const Color(0xFF9DF6FF),
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.workspace_premium_rounded,
                              title: 'Plan',
                              value: plan.toUpperCase(),
                              color: const Color(0xFFFFC857),
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.verified_user_rounded,
                              title: 'Status',
                              value: 'ACTIVE',
                              color: const Color(0xFF34F087),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      OrdifyGlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              height: 52,
                              width: 52,
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                color: Colors.redAccent,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sign Out',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Logout from this OrdiFy account.',
                                    style: GoogleFonts.inter(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: signOut,
                              child: Text(
                                'Logout',
                                style: GoogleFonts.inter(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w900,
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
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.onRefresh,
  });

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account center',
                style: TextStyle(
                  color: Color(0xFFE8FFF2),
                  fontWeight: FontWeight.w700,
                ),
              ),
              _GlowText(
                'Settings',
                fontSize: 26,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(
            Icons.refresh_rounded,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF34F087),
        ),
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: const Color(0xFFE8FFF2),
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.16),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFF34F087),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFFE8FFF2),
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowText extends StatelessWidget {
  const _GlowText(
    this.text, {
    required this.fontSize,
    this.soft = false,
  });

  final String text;
  final double fontSize;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(
            color: soft ? const Color(0xFFFFC8C8) : const Color(0xFFFFD6D6),
            blurRadius: soft ? 8 : 12,
          ),
          Shadow(
            color: const Color(0xFF34F087).withOpacity(0.25),
            blurRadius: soft ? 8 : 14,
          ),
        ],
      ),
    );
  }
}