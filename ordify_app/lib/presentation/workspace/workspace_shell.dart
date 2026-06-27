import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/auth/auth_notifier.dart';

class WorkspaceShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const WorkspaceShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 68,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                label: 'Customers',
              ),
              _navItem(
                index: 4,
                icon: Icons.psychology_rounded,
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

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        );
      },
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: isActive ? const Color(0xFF00FFCC) : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: isActive ? const Color(0xFF00FFCC) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoutItem(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
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
          await ref.read(authProvider.notifier).signOut();
        }
      },
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.logout_rounded,
              size: 21,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 4),
            Text(
              'Logout',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}