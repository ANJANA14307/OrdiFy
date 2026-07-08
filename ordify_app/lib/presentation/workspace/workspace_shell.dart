import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/auth/auth_notifier.dart';
import 'ordify_workspace_widgets.dart';

class WorkspaceShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const WorkspaceShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ordifyBg,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 72,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1510).withOpacity(0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withOpacity(0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.38),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              _navItem(
                index: 0,
                icon: Icons.grid_view_rounded,
                label: 'Home',
              ),
              _navItem(
                index: 1,
                icon: Icons.receipt_long_rounded,
                label: 'Orders',
              ),
              _navItem(
                index: 2,
                icon: Icons.inventory_2_rounded,
                label: 'Stock',
              ),
              _navItem(
                index: 3,
                icon: Icons.people_alt_rounded,
                label: 'CRM',
              ),
              _navItem(
                index: 4,
                icon: Icons.auto_awesome_rounded,
                label: 'AI',
              ),
              _logoutItem(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isActive = index == navigationShell.currentIndex;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? ordifyGreen.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 21,
                color: isActive ? ordifyGreen : Colors.white38,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: isActive ? ordifyGreen : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoutItem(BuildContext context, WidgetRef ref) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                backgroundColor: const Color(0xFF101A15),
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
                  'You can log in again anytime.',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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
                        color: ordifyRed,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              );
            },
          );

          if (shouldLogout == true) {
            await ref.read(authProvider.notifier).signOut();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.logout_rounded,
                size: 21,
                color: ordifyRed,
              ),
              const SizedBox(height: 4),
              Text(
                'Exit',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: ordifyRed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}